import { pipeline, env } from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2/dist/transformers.min.js";

const MODEL_ID = "onnx-community/whisper-large-v3-turbo";

// Chrome'un Cache Storage'ı tek parçada ~250 MB üstü dosyalarda
// "Unexpected internal error" ile başarısız oluyor (bu Mac'te ölçüldü;
// kullanıcının kendi Chrome'unda aynı belirti - model her seferinde yeniden
// inme - doğrulandı). Whisper'ın encoder/decoder dosyaları bundan büyük
// olduğu için önbelleğe hiç yazılmıyor ve her seferinde yeniden iniyordu.
// Çözüm: büyük dosyaları küçük parçalara bölüp her parçayı ayrı bir
// önbellek kaydı olarak saklamak.
const CHUNK_BYTES = 128 * 1024 * 1024;

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
  static device = null;

  static async getInstance(device, progress_callback) {
    if (!this.instance) {
      this.device = device;
      this.instance = pipeline("automatic-speech-recognition", MODEL_ID, {
        ...DEVICE_CONFIG[device],
        progress_callback,
      });
    }
    return this.instance;
  }
}

async function load({ device }) {
  const t0 = performance.now();
  const transcriber = await PipelineSingleton.getInstance(device, (x) => {
    self.postMessage({ status: "progress", data: x });
  });

  self.postMessage({ status: "loading", data: "Model ısınıyor..." });
  await transcriber(new Float32Array(16_000), { language: "turkish" });

  self.postMessage({ status: "ready", loadMs: performance.now() - t0 });
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
