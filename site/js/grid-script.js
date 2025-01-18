class Hyperlisp {
  constructor() {
    this.vm = null;
    this.load();
  }

  async load() {
    if (this.vm) {
      return;
    }
    this.vm = await WebAssembly.instantiateStreaming(
      fetch("js/hyperlisp.wasm"),
      {
        env: {
          sendString: (ptr, len) => {
            const bytes = new Uint8Array(
              this.vm.instance.exports.memory.buffer,
              ptr,
              len,
            );
            const string = new TextDecoder().decode(bytes);
            console.log("Recieved response", string);
          },
          log: (level, ptr, len) => {
            const bytes = new Uint8Array(
              this.vm.instance.exports.memory.buffer,
              ptr,
              len,
            );
            const string = new TextDecoder().decode(bytes);
            switch (level) {
              case 0:
                console.error(string);
                break;
              case 1:
                console.warn(string);
                break;
              case 2:
                console.info(string);
                break;
              case 3:
                console.debug(string);
                break;
              default:
                console.log(string);
                break;
            }
          },
          logUint: (level, value) => {
            switch (level) {
              case 0:
                console.error(value);
                break;
              case 1:
                console.warn(value);
                break;
              case 2:
                console.info(value);
                break;
              case 3:
                console.debug(value);
                break;
              default:
                console.log(value);
                break;
            }
          },
        },
      },
    );
  }

  async run(str) {
    if (!this.vm) {
      await this.load();
    }
    let encoder = new TextEncoder();
    let bytes = encoder.encode(str);
    let addr = this.vm.instance.exports.alloc(bytes.byteLength);
    let dest = new Uint8Array(
      this.vm.instance.exports.memory.buffer,
      addr,
      bytes.byteLength,
    );
    new TextEncoder().encodeInto(str, dest);
    const res = this.vm.instance.exports.eval(addr, bytes.byteLength);
    console.log("Result from run", res, ret);
    this.vm.instance.exports.free(addr, str.byteLength);
  }
}

class GridScript extends HTMLScriptElement {
  constructor() {
    super();
    if (!window.HYPERLISP) {
      window.HYPERLISP = new Hyperlisp();
    }
  }
  connectedCallback() {
    console.info("Inner", this.innerText);
    if (window.HYPERLISP) {
      window.HYPERLISP.run(this.innerText.trim());
    }
    this.innerHTML = "<p>Hyperlisp loaded and running</p>";
  }

  attributeChangedCallback(name, oldValue, newValue) {
    console.log(`Attribute ${name} has changed.`);
  }
}
