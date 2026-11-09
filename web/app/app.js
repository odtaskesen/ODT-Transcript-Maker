import { parseSRT, serializeSRT, segmentsFromChunks } from "./srt.mjs";

const LANGUAGES = [
  { code: "turkish", title: "Türkçe" },
  { code: "english", title: "İngilizce" },
  { code: "german", title: "Almanca" },
  { code: "dutch", title: "Felemenkçe" },
  { code: "spanish", title: "İspanyolca" },
];

const els = {
  languageSelect: document.getElementById("language-select"),
  modelStatus: document.getElementById("model-status"),
  dropzone: document.getElementById("dropzone"),
  fileInput: document.getElementById("file-input"),
  queueList: document.getElementById("queue-list"),
  gpuNotice: document.getElementById("gpu-notice"),
};

let device = "wasm";
let worker = null;
let modelState = "unloaded"; // unloaded | loading | ready
let queue = []; // { id, file, status, resultText, chunks, editedText, segments, startedAt }
let nextId = 1;
let processing = false;

function uid() {
  return nextId++;
}

function setModelStatus(text) {
  els.modelStatus.textContent = text;
}

function createWorker() {
  worker = new Worker("./worker.js", { type: "module" });
  worker.addEventListener("message", onWorkerMessage);
  return worker;
}

function onWorkerMessage(e) {
  const msg = e.data;
  if (msg.status === "progress") {
    if (msg.data && msg.data.file) {
      const pct = msg.data.progress ? ` ${msg.data.progress.toFixed(0)}%` : "";
      setModelStatus(`Model indiriliyor: ${msg.data.file}${pct}`);
    }
  } else if (msg.status === "loading") {
    setModelStatus(typeof msg.data === "string" ? msg.data : "Model hazırlanıyor...");
  } else if (msg.status === "ready") {
    modelState = "ready";
    setModelStatus(`Model hazır (${(msg.loadMs / 1000).toFixed(0)} sn).`);
    processQueue();
  } else if (msg.status === "complete") {
    onJobComplete(msg.jobId, msg.result, msg.inferenceMs);
  } else if (msg.status === "error") {
    onJobError(msg.jobId, msg.error);
  }
}

async function ensureModel() {
  if (modelState === "ready") return;
  if (modelState === "loading") return;
  modelState = "loading";
  if (!worker) createWorker();
  setModelStatus("Model hazırlanıyor (ilk seferde biraz sürebilir)...");
  worker.postMessage({ type: "load", data: { device } });
}

function findItem(id) {
  return queue.find((q) => q.id === id);
}

async function processQueue() {
  if (processing) return;
  if (modelState !== "ready") {
    ensureModel();
    return;
  }
  const next = queue.find((q) => q.status === "pending");
  if (!next) return;
  processing = true;
  next.status = "processing";
  next.startedAt = performance.now();
  render();

  try {
    setItemProgressText(next.id, "Ses dosyadan çözülüyor...");
    const buf = await next.file.arrayBuffer();
    const { samples } = await decodeToMono16k(buf);
    if (next.status !== "processing") {
      // Bu sırada iptal edildiyse devam etme.
      processing = false;
      processQueue();
      return;
    }
    setItemProgressText(next.id, "Yazıya çevriliyor...");
    worker.postMessage(
      { type: "run", data: { jobId: next.id, audio: samples, language: next.language } },
      [samples.buffer]
    );
  } catch (err) {
    onJobError(next.id, String(err && err.message ? err.message : err));
  }
}

function setItemProgressText(id, text) {
  const item = findItem(id);
  if (!item) return;
  item.progressText = text;
  render();
}

function onJobComplete(jobId, result, inferenceMs) {
  const item = findItem(jobId);
  if (!item) return;
  if (item.status !== "processing") {
    // İptal edilmiş bir işin geç gelen sonucu; yok say.
    processing = false;
    processQueue();
    return;
  }
  const text = (result.text || "").trim();
  const chunks = result.chunks || [];
  item.status = "done";
  item.inferenceMs = inferenceMs;
  item.resultText = text;
  item.editedText = text;
  item.segments = segmentsFromChunks(chunks);
  item.activeTab = "metin";
  processing = false;
  render();
  processQueue();
}

function onJobError(jobId, error) {
  console.error(error);
  const item = jobId != null ? findItem(jobId) : null;
  if (item) {
    item.status = "error";
    item.errorText = "Bir hata oluştu. Bu dosyayı atlayıp devam edebilirsiniz.";
  }
  processing = false;
  render();
  processQueue();
}

function cancelItem(id) {
  const item = findItem(id);
  if (!item || item.status !== "processing") return;
  item.status = "cancelled";
  // Devam eden çıkarımı güvenle durdurmanın tek yolu worker'ı sonlandırmak;
  // bunun bedeli, bir sonraki dosya için modelin yeniden yüklenmesidir
  // (tarayıcı önbelleğe aldıysa yeniden indirme gerekmeyebilir).
  if (worker) {
    worker.removeEventListener("message", onWorkerMessage);
    worker.terminate();
    worker = null;
  }
  modelState = "unloaded";
  processing = false;
  render();
  ensureModel();
}

function addFiles(fileList) {
  const language = els.languageSelect.value;
  for (const file of fileList) {
    queue.push({
      id: uid(),
      file,
      language,
      status: "pending",
      progressText: "Sırada bekliyor...",
    });
  }
  render();
  ensureModel();
  processQueue();
}

async function decodeToMono16k(arrayBuffer) {
  const ctx = new (window.AudioContext || window.webkitAudioContext)();
  const audioBuffer = await ctx.decodeAudioData(arrayBuffer);
  const duration = audioBuffer.duration;
  const offlineCtx = new OfflineAudioContext(1, Math.ceil(duration * 16000), 16000);
  const source = offlineCtx.createBufferSource();
  source.buffer = audioBuffer;
  source.connect(offlineCtx.destination);
  source.start(0);
  const rendered = await offlineCtx.startRendering();
  return { samples: rendered.getChannelData(0), duration };
}

function downloadText(filename, content) {
  const blob = new Blob([content], { type: "text/plain;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

function baseName(filename) {
  return filename.replace(/\.[^.]+$/, "");
}

function statusLabel(item) {
  switch (item.status) {
    case "pending":
      return "Bekliyor";
    case "processing":
      return "İşleniyor";
    case "done":
      return "Tamam";
    case "error":
      return "Hata";
    case "cancelled":
      return "İptal edildi";
    default:
      return item.status;
  }
}

function render() {
  els.queueList.innerHTML = "";
  for (const item of queue) {
    const card = document.createElement("div");
    card.className = `queue-item status-${item.status}`;

    const header = document.createElement("div");
    header.className = "queue-item-header";
    header.innerHTML = `
      <span class="queue-item-name">${escapeHtml(item.file.name)}</span>
      <span class="queue-item-status">${statusLabel(item)}</span>
    `;
    card.appendChild(header);

    if (item.status === "processing") {
      const p = document.createElement("div");
      p.className = "queue-item-progress";
      p.textContent = item.progressText || "";
      const cancelBtn = document.createElement("button");
      cancelBtn.textContent = "İptal et";
      cancelBtn.className = "btn-secondary";
      cancelBtn.onclick = () => cancelItem(item.id);
      p.appendChild(cancelBtn);
      card.appendChild(p);
    }

    if (item.status === "error") {
      const p = document.createElement("div");
      p.className = "queue-item-error";
      p.textContent = item.errorText || "Hata oluştu.";
      card.appendChild(p);
    }

    if (item.status === "done") {
      card.appendChild(renderResult(item));
    }

    els.queueList.appendChild(card);
  }
}

function renderResult(item) {
  const wrap = document.createElement("div");
  wrap.className = "queue-item-result";

  const tabs = document.createElement("div");
  tabs.className = "tabs";
  const metinTab = document.createElement("button");
  metinTab.textContent = "Metin";
  metinTab.className = item.activeTab === "metin" ? "tab active" : "tab";
  metinTab.onclick = () => {
    item.activeTab = "metin";
    render();
  };
  const srtTab = document.createElement("button");
  srtTab.textContent = "SRT";
  srtTab.className = item.activeTab === "srt" ? "tab active" : "tab";
  srtTab.onclick = () => {
    item.activeTab = "srt";
    render();
  };
  tabs.appendChild(metinTab);
  tabs.appendChild(srtTab);
  wrap.appendChild(tabs);

  if (item.activeTab === "srt") {
    const list = document.createElement("div");
    list.className = "srt-segments";
    item.segments.forEach((seg, idx) => {
      const row = document.createElement("div");
      row.className = "srt-segment";
      const time = document.createElement("div");
      time.className = "srt-time";
      time.textContent = `${seg.startTime} → ${seg.endTime}`;
      const textArea = document.createElement("textarea");
      textArea.value = seg.text;
      textArea.rows = 2;
      textArea.oninput = (e) => {
        item.segments[idx].text = e.target.value;
      };
      row.appendChild(time);
      row.appendChild(textArea);
      list.appendChild(row);
    });
    wrap.appendChild(list);

    const dlBtn = document.createElement("button");
    dlBtn.textContent = "SRT indir";
    dlBtn.onclick = () => downloadText(`${baseName(item.file.name)}.srt`, serializeSRT(item.segments));
    wrap.appendChild(dlBtn);
  } else {
    const textArea = document.createElement("textarea");
    textArea.className = "metin-editor";
    textArea.value = item.editedText;
    textArea.rows = 8;
    textArea.oninput = (e) => {
      item.editedText = e.target.value;
    };
    wrap.appendChild(textArea);

    const dlBtn = document.createElement("button");
    dlBtn.textContent = "TXT indir";
    dlBtn.onclick = () => downloadText(`${baseName(item.file.name)}.txt`, item.editedText);
    wrap.appendChild(dlBtn);
  }

  return wrap;
}

function escapeHtml(s) {
  const div = document.createElement("div");
  div.textContent = s;
  return div.innerHTML;
}

function init() {
  for (const lang of LANGUAGES) {
    const opt = document.createElement("option");
    opt.value = lang.code;
    opt.textContent = lang.title;
    els.languageSelect.appendChild(opt);
  }
  els.languageSelect.value = "turkish";

  els.fileInput.addEventListener("change", (e) => {
    addFiles(e.target.files);
    e.target.value = "";
  });

  els.dropzone.addEventListener("click", () => els.fileInput.click());
  els.dropzone.addEventListener("dragover", (e) => {
    e.preventDefault();
    els.dropzone.classList.add("dragover");
  });
  els.dropzone.addEventListener("dragleave", () => els.dropzone.classList.remove("dragover"));
  els.dropzone.addEventListener("drop", (e) => {
    e.preventDefault();
    els.dropzone.classList.remove("dragover");
    addFiles(e.dataTransfer.files);
  });

  checkWebGPU();
  setModelStatus("Henüz yüklenmedi. İlk dosya eklendiğinde otomatik hazırlanır.");
}

async function checkWebGPU() {
  if (!navigator.gpu) {
    device = "wasm";
    els.gpuNotice.textContent =
      "Bu tarayıcıda WebGPU bulunamadı; işlem yazılım üzerinden (çok daha yavaş) yapılacak. Chrome veya Edge'in güncel bir sürümünü deneyin.";
    return;
  }
  try {
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) {
      device = "wasm";
      els.gpuNotice.textContent = "WebGPU bulunamadı; işlem yazılım üzerinden yapılacak.";
      return;
    }
    device = "webgpu";
    els.gpuNotice.textContent = "";
  } catch {
    device = "wasm";
    els.gpuNotice.textContent = "WebGPU kontrolünde hata oluştu; işlem yazılım üzerinden yapılacak.";
  }
}

init();
