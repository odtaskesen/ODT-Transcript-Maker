import { pipeline, env } from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2/dist/transformers.min.js";

// Optimal: large-v3-turbo — daha az hata, daha büyük indirme, daha yavaş.
// Hafif: small — daha hızlı ve küçük, ama özellikle Türkçe gibi dillerde
// belirgin ölçüde daha çok hata yapar (bkz. docs/WEB_VERSION_PLAN.md).
const MODEL_CONFIGS = {
  optimal: { modelId: "onnx-community/whisper-large-v3-turbo" },
  lite: { modelId: "onnx-community/whisper-small" },
};

// Chrome'un Cache Storage'ı tek parçada ~250 MB üstü dosyalarda
// "Unexpected internal error" ile başarısız oluyor (bu Mac'te ölçüldü;
// kullanıcının kendi Chrome'unda aynı belirti - model her seferinde yeniden
// inme - doğrulandı). Whisper'ın encoder/decoder dosyaları bundan büyük
// olduğu için önbelleğe hiç yazılmıyor ve her seferinde yeniden iniyordu.
// Çözüm: büyük dosyaları küçük parçalara bölüp her parçayı ayrı bir
// önbellek kaydı olarak saklamak.
const CHUNK_BYTES = 128 * 1024 * 1024;

// Model ağırlık dosyaları (.onnx) önbellekten mi geldi, yoksa indirildi mi —
// kullanıcıya doğru durum metni göstermek için (bkz. load()).
const cacheState = { usedModelWeightsFromCache: false };

class ChunkedCache {
  #cache;

  async #getCache() {
    this.#cache ??= await caches.open("transformers-chunked-cache-v1");
    return this.#cache;
  }

  async match(key) {
    const cache = await this.#getCache();
    const manifestResp = await cache.match(`${key}::manifest`);
    if (!manifestResp) return undefined;
    const manifest = await manifestResp.json();
    const parts = [];
    for (let i = 0; i < manifest.chunkCount; i++) {
      const chunkResp = await cache.match(`${key}::chunk${i}`);
      if (!chunkResp) return undefined; // eksik parça varsa yeniden indirilsin
      parts.push(await chunkResp.blob());
    }
    if (key.endsWith(".onnx")) cacheState.usedModelWeightsFromCache = true;
    return new Response(new Blob(parts), { headers: manifest.headers });
  }

  async put(key, response) {
    const cache = await this.#getCache();
    const buffer = new Uint8Array(await response.arrayBuffer());
    const chunkCount = Math.max(1, Math.ceil(buffer.byteLength / CHUNK_BYTES));
    for (let i = 0; i < chunkCount; i++) {
      const start = i * CHUNK_BYTES;
      const chunk = buffer.subarray(start, start + CHUNK_BYTES);
      await cache.put(`${key}::chunk${i}`, new Response(chunk));
    }
    const headers = Object.fromEntries(response.headers.entries());
    await cache.put(
      `${key}::manifest`,
      new Response(JSON.stringify({ chunkCount, headers }))
    );
  }
}

env.useCustomCache = true;
env.customCache = new ChunkedCache();

const DEVICE_CONFIG = {
  webgpu: {
    dtype: {
      encoder_model: "fp16",
      decoder_model_merged: "q4",
    },
    device: "webgpu",
  },
  wasm: {
    dtype: "q8",
    device: "wasm",
  },
};

class PipelineSingleton {
  static instance = null;

  static async getInstance(device, mode, progress_callback) {
    if (!this.instance) {
      const { modelId } = MODEL_CONFIGS[mode];
      this.instance = pipeline("automatic-speech-recognition", modelId, {
        ...DEVICE_CONFIG[device],
        progress_callback,
      });
    }
    return this.instance;
  }
}

async function load({ device, mode }) {
  const t0 = performance.now();
  // pipeline() dahili olarak progress_callback'imizi bir toplama katmanıyla
  // sarıyor ve "progress_total" olaylarında tüm dosyalar üzerinden tek bir
  // yüzde veriyor (per-dosya olaylar yerine bunu kullanıyoruz, çünkü
  // onlar her dosyada sıfırdan başlayıp ilerleme çubuğunu geri sıçratır).
  const transcriber = await PipelineSingleton.getInstance(device, mode, (x) => {
    if (x.status === "progress_total") {
      self.postMessage({ status: "progress", progress: x.progress });
    }
  });

  self.postMessage({ status: "loading", data: "Model ısınıyor..." });
  await transcriber(new Float32Array(16_000), { language: "turkish" });

  self.postMessage({
    status: "ready",
    loadMs: performance.now() - t0,
    fromCache: cacheState.usedModelWeightsFromCache,
  });
}

async function run({ jobId, audio, language }) {
  const transcriber = await PipelineSingleton.getInstance();
  const t0 = performance.now();
  const result = await transcriber(audio, {
    language,
    chunk_length_s: 30,
    return_timestamps: true,
  });
  self.postMessage({ status: "complete", jobId, result, inferenceMs: performance.now() - t0 });
}

self.addEventListener("message", async (e) => {
  const { type, data } = e.data;
  try {
    if (type === "load") await load(data);
    else if (type === "run") await run(data);
  } catch (err) {
    self.postMessage({
      status: "error",
      jobId: data && data.jobId,
      error: String(err && err.stack ? err.stack : err),
    });
  }
});
