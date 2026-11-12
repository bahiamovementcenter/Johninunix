const V = "0.7.0";
const CDN = "https://cdn.jsdelivr.net/npm/@myriaddreamin";
let typst; // one compiler per page, shared by every widget

async function getTypst() {
  if (!typst) {
    typst = import(`${CDN}/typst.ts@${V}/dist/esm/contrib/all-in-one-lite.bundle.js`)
      .then(({ $typst }) => {
        $typst.setCompilerInitOptions({ getModule: () => `${CDN}/typst-ts-web-compiler@${V}/pkg/typst_ts_web_compiler_bg.wasm` });
        $typst.setRendererInitOptions({ getModule: () => `${CDN}/typst-ts-renderer@${V}/pkg/typst_ts_renderer_bg.wasm` });
        return $typst;
      });
  }
  return typst;
}

function inputsPrelude(inputs) {
  // expose Python values to Typst as `#let inputs = (...)` (JSON-decoded)
  return `#let inputs = json(bytes(${JSON.stringify(JSON.stringify(inputs ?? {}))}))\n`;
}

async function render({ model, el }) {
  el.classList.add("typst-widget");
  const editor = document.createElement("textarea");
  const out = document.createElement("div");
  const err = document.createElement("pre");
  editor.style.cssText = "width:100%;min-height:8em;font-family:monospace;box-sizing:border-box";
  err.style.cssText = "color:#c00;white-space:pre-wrap;margin:0";
  out.style.cssText = "overflow-x:auto";
  const controls = document.createElement("div");
  controls.style.cssText = "display:flex;gap:1em;flex-wrap:wrap;margin:.25em 0";
  el.append(controls, editor, out, err);

  // Controls rendered in the browser: they work even with no Python kernel
  // (static HTML export), because they feed `inputs` straight into Typst.
  const buildControls = () => {
    controls.replaceChildren();
    for (const [name, spec] of Object.entries(model.get("controls") ?? {})) {
      const label = document.createElement("label");
      const input = document.createElement("input");
      const shown = document.createElement("span");
      input.type = "range";
      input.min = spec.min ?? 0; input.max = spec.max ?? 100; input.step = spec.step ?? 1;
      input.value = (model.get("inputs") ?? {})[name] ?? spec.value ?? input.min;
      shown.textContent = input.value;
      input.addEventListener("input", () => {
        shown.textContent = input.value;
        model.set("inputs", { ...(model.get("inputs") ?? {}), [name]: Number(input.value) });
        model.save_changes();
        draw();
      });
      label.append(`${name} `, input, " ", shown);
      controls.append(label);
    }
  };

  let seq = 0;
  const draw = async () => {
    const mine = ++seq;
    editor.hidden = !model.get("editable");
    if (document.activeElement !== editor) editor.value = model.get("source");
    try {
      const $typst = await getTypst();
      const svg = await $typst.svg({ mainContent: inputsPrelude(model.get("inputs")) + model.get("source") });
      if (mine !== seq) return; // a newer edit already won
      out.innerHTML = svg;
      err.textContent = "";
      model.set("error", "");
    } catch (e) {
      if (mine !== seq) return;
      err.textContent = String(e);
      model.set("error", String(e));
    }
    model.save_changes();
  };

  let t;
  editor.addEventListener("input", () => {
    clearTimeout(t);
    t = setTimeout(() => { model.set("source", editor.value); model.save_changes(); draw(); }, 200);
  });
  model.on("change:source", draw);
  model.on("change:inputs", draw);
  model.on("change:editable", draw);
  model.on("change:controls", buildControls);
  buildControls();
  draw();
}

export default { render };
