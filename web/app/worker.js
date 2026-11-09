import { pipeline } from "https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2/dist/transformers.min.js";

const MODEL_ID = "onnx-community/whisper-large-v3-turbo";

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
