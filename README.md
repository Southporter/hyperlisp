# Hyperlisp
Hyperlisp is an alternative web scripting language alternative to JavaScript. It is inspired by Dylan Beattie's [The Web That Never Was](https://www.youtube.com/watch?v=9CSjlZeqKOc). 


## Repl
You can try out Hyperlisp in your terminal. To run, you will need Zig 0.14 (currently the dev version) and readline.

```bash
zig build run
```
See the [tutorial](docs/tutorial.md) for a more in deprth look at the synatx and semantics.

## Web
Since Hyperlisp is a (hypothetical) replacement for JavaScript, the primary target is Web/Grid browsers. Since browsers do not natively support Hyperlisp, this project leverages WebAssembly to embed the runtime in the web page.
This runtime includes the bridge code (in JavaScript) for allowing Hyperlisp access to the Dom and other browser apis. The goal is for this bridge to act as if Hyperlisp was provided by the browser as another language available in `<script>` tags.
