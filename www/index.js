class WasmHandler {
  constructor() {
    this.memory = null;
  }

  logWasm(s, len) {
    const buf = new Uint8Array(this.memory.buffer, s, len);
    if (len === 0) {
      return;
    }
    console.log(new TextDecoder("utf8").decode(buf));
  }
}

async function instantiateWasmModule(wasm_handlers) {
  const wasmEnv = {
    env: {
      logWasm: wasm_handlers.logWasm.bind(wasm_handlers),
    },
  };

  const mod = await WebAssembly.instantiateStreaming(
    fetch("search.wasm"),
    wasmEnv,
  );
  wasm_handlers.memory = mod.instance.exports.memory;
  wasm_handlers.mod = mod;

  return mod;
}

async function init() {
  const wasm_handlers = new WasmHandler();
  const mod = await instantiateWasmModule(wasm_handlers);

  mod.instance.exports.main();
  mod.instance.exports.listStemmer();
}

window.onload = init;
