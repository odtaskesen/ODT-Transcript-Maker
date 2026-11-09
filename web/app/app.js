import { parseSRT, serializeSRT, segmentsFromChunks } from "./srt.mjs";
import { CHATGPT_ACTIONS, buildPrompt } from "./chatgpt-prompts.mjs";

const LANGUAGES = [
  { code: "turkish", title: "Türkçe" },
  { code: "english", title: "İngilizce" },
  { code: "german", title: "Almanca" },
  { code: "dutch", title: "Felemenkçe" },
  { code: "spanish", title: "İspanyolca" },
];

const els = {
  languageSelect: document.getElementById("language-select"),
  modeSelect: document.getElementById("mode-select"),
  modelStatus: document.getElementById("model-status"),
  dropzone: document.getElementById("dropzone"),
  fileInput: document.getElementById("file-input"),
  queueList: document.getElementById("queue-list"),
  gpuNotice: document.getElementById("gpu-notice"),
  updateBanner: document.getElementById("update-banner"),
  updateBtn: document.getElementById("update-btn"),
};

let device = "wasm";
let worker = null;
let modelState = "unloaded"; // unloaded | loading | ready
let modelMode = "optimal"; // optimal | lite — worker şu an hangi model için yüklü/yükleniyor
let queue = []; // { id, file, status, resultText, chunks, editedText, segments, startedAt }
let nextId = 1;
let processing = false;

function uid() {
  return nextId++;
}

function setModelStatus(text, variant = "muted") {
  els.modelStatus.textContent = text;
  els.modelStatus.className = `meta-line ${variant}`;
}

function createWorker() {
  worker = new Worker("./worker.js", { type: "module" });
  worker.addEventListener("message", onWorkerMessage);
  return worker;
}

function blockBar(percent, width = 20) {
  const filled = Math.max(0, Math.min(width, Math.round((percent / 100) * width)));
  return "█".repeat(filled) + "░".repeat(width - filled);
}

function onWorkerMessage(e) {
  const msg = e.data;
  if (msg.status === "progress") {
    // Bu aşama hem internetten indirmeyi hem diskteki önbellekten okumayı
    // kapsar (ikisi de aynı şekilde ilerler); hangisi olduğu yalnızca
    // bitince "ready" mesajındaki fromCache alanıyla netleşiyor.
    setModelStatus(`Model hazırlanıyor ${blockBar(msg.progress)} ${msg.progress.toFixed(0)}%`, "progress-bar");
  } else if (msg.status === "loading") {
    setModelStatus(typeof msg.data === "string" ? msg.data : "Model hazırlanıyor...", "muted");
  } else if (msg.status === "ready") {
    modelState = "ready";
    const seconds = (msg.loadMs / 1000).toFixed(0);
    const modeLabel = modelMode === "lite" ? "Hafif mod" : "Optimal mod";
    setModelStatus(
      msg.fromCache
        ? `${modeLabel} diskten yüklendi (${seconds} sn, yeniden indirilmedi).`
        : `${modeLabel} indirildi ve hazırlandı (${seconds} sn).`,
      "muted"
    );
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
  worker.postMessage({ type: "load", data: { device, mode: modelMode } });
}

function setMode(mode) {
  if (mode === modelMode) return;
  if (processing) return; // Aktif işlem sırasında mod değişimine izin verme.
  modelMode = mode;
  // Şu an yüklü/yüklenmekte olan model başka moda ait; worker'ı sonlandırıp
  // bir sonraki dosyada doğru modelin yüklenmesini sağla.
  if (worker) {
    worker.removeEventListener("message", onWorkerMessage);
    worker.terminate();
    worker = null;
  }
  modelState = "unloaded";
  setModelStatus("Henüz yüklenmedi. İlk dosya eklendiğinde otomatik hazırlanır.");
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
      <span class="dot-leader"></span>
      <span class="queue-item-status">${statusLabel(item)}</span>
    `;
    card.appendChild(header);

    if (item.status === "processing") {
      const p = document.createElement("div");
      p.className = "queue-item-progress";
      const span = document.createElement("span");
      span.textContent = item.progressText || "";
      p.appendChild(span);
      const cancelBtn = document.createElement("button");
      cancelBtn.textContent = "İptal et";
      cancelBtn.className = "key-button";
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
  tabs.className = "toggle-row";
  const metinTab = document.createElement("button");
  metinTab.textContent = "Metin";
  metinTab.className = item.activeTab === "metin" ? "toggle-option active" : "toggle-option";
  metinTab.onclick = () => {
    item.activeTab = "metin";
    render();
  };
  const dot = document.createElement("span");
  dot.className = "toggle-dot";
  dot.textContent = "·";
  const srtTab = document.createElement("button");
  srtTab.textContent = "SRT";
  srtTab.className = item.activeTab === "srt" ? "toggle-option active" : "toggle-option";
  srtTab.onclick = () => {
    item.activeTab = "srt";
    render();
  };
  tabs.appendChild(metinTab);
  tabs.appendChild(dot);
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
    dlBtn.className = "key-button";
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
    dlBtn.className = "key-button";
    dlBtn.onclick = () => downloadText(`${baseName(item.file.name)}.txt`, item.editedText);
    wrap.appendChild(dlBtn);

    wrap.appendChild(renderChatGPTTools(item));
  }

  return wrap;
}

function renderChatGPTTools(item) {
  const wrap = document.createElement("div");
  wrap.className = "chatgpt-tools";

  const label = document.createElement("div");
  label.className = "meta-line muted";
  label.textContent = "ChatGPT araçları";
  wrap.appendChild(label);

  const row = document.createElement("div");
  row.className = "chatgpt-tools-row";
  for (const action of CHATGPT_ACTIONS) {
    const btn = document.createElement("button");
    btn.textContent = action.title;
    btn.className = "key-button";
    btn.onclick = () => sendToChatGPT(item, action);
    row.appendChild(btn);
  }
  wrap.appendChild(row);

  if (item.chatgptMessage) {
    const msg = document.createElement("div");
    msg.className = "meta-line muted";
    msg.textContent = item.chatgptMessage;
    wrap.appendChild(msg);
  }

  return wrap;
}

async function sendToChatGPT(item, action) {
  const prompt = buildPrompt(action, item.editedText);
  try {
    await navigator.clipboard.writeText(prompt);
    item.chatgptMessage = action.copiedMessage;
  } catch {
    item.chatgptMessage = "Panoya kopyalanamadı. Metni elle kopyalayabilirsiniz.";
  }
  window.open("https://chatgpt.com/", "_blank", "noopener");
  render();
  clearTimeout(item._chatgptMessageTimer);
  item._chatgptMessageTimer = setTimeout(() => {
    item.chatgptMessage = null;
    render();
  }, 4000);
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

  els.modeSelect.value = modelMode;
  els.modeSelect.addEventListener("change", (e) => setMode(e.target.value));

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
  registerServiceWorker();
}

function registerServiceWorker() {
  if (!("serviceWorker" in navigator)) return;
  navigator.serviceWorker.register("./sw.js").catch((err) => {
    console.warn("Servis çalışanı kaydedilemedi:", err);
  });

  // Yeni bir servis çalışanı devreye girdiğinde (site güncellendiğinde)
  // kullanıcıyı eski, önbellekte takılı kalmış bir sürümde bırakmamak için
  // yenileme çağrısı göster.
  let refreshed = false;
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (refreshed) return;
    refreshed = true;
    if (document.hidden) {
      location.reload();
    } else {
      els.updateBanner.hidden = false;
      els.updateBtn.onclick = () => location.reload();
    }
  });
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
