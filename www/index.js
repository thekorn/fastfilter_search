class WasmHandler {
  constructor() {
    this.memory = null;
  }

  /**
   * @param {string} len
   * @param {number} offset
   */
  logWasm(offset, len) {
    /** @type {ArrayBuffer} */
    const buf = new Uint8Array(this.memory.buffer, offset, len);
    if (len === 0) {
      return;
    }
    console.log(new TextDecoder("utf8").decode(buf));
  }
}

/**
 * @param {WebAssembly.WebAssemblyInstantiatedSource} mod
 * @param {string} uri
 * @param {(len: number) => void} pushFn
 */
async function loadDataFromServer(uri, mod, pushFn) {
  const data_response = await fetch(uri);
  const data_reader = data_response.body.getReader({
    mode: "byob",
  });
  let array_buf = new ArrayBuffer(16384);
  while (true) {
    const { value, done } = await data_reader.read(new Uint8Array(array_buf));
    if (done) break;

    array_buf = value.buffer;
    const chunk_buf = new Uint8Array(
      mod.instance.exports.memory.buffer,
      mod.instance.exports.global_chunk.value,
      16384,
    );
    chunk_buf.set(value);
    pushFn(value.length);
  }
}

/**
 * @param {WebAssembly.WebAssemblyInstantiatedSource} mod
 * @param {string} string
 */
function encodeString(mod, string) {
  const buffer = new TextEncoder().encode(string);
  const slice = new Uint8Array(
    mod.instance.exports.memory.buffer,
    mod.instance.exports.global_chunk.value,
    buffer.length + 1,
  );
  slice.set(buffer);
  slice[buffer.length] = 0;
  return buffer.length;
}

/**
 * @param {WebAssembly.WebAssemblyInstantiatedSource} mod
 */
async function loadTextIndex(mod) {
  await loadDataFromServer(
    "search.idx",
    mod,
    mod.instance.exports.pushTextIndexData,
  );
}

/**
 * @param {WasmHandler} wasm_handlers
 */
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

  await loadTextIndex(mod);
  mod.instance.exports.init();

  /** @type {HTMLButtonElement} */
  const search_button = document.getElementById("search_button");
  /** @type {HTMLInputElement} */
  const search_input = document.getElementById("search_input");
  search_button.onclick = () => {
    console.log("click", search_input.value);
    mod.instance.exports.search(encodeString(mod, search_input.value));
  };
}

window.onload = init;
