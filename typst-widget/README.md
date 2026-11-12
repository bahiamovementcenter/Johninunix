# typst-widget

Typst documents in [marimo](https://marimo.io) notebooks (and anything else
that hosts an [anywidget](https://anywidget.dev)), compiled in the browser
with [typst.ts](https://github.com/Myriad-Dreamin/typst.ts).

```python
import marimo as mo
from typst_widget import Typst

n = mo.ui.slider(1, 10, value=3)

mo.ui.anywidget(Typst(
    "#set page(width: auto, height: auto, margin: 8pt)\n"
    "$ sum_(i=1)^(#inputs.n) i^2 $",
    inputs={"n": n.value},
    editable=True,
))
```

## What it does

| Field | What it's for |
| --- | --- |
| `source` | the Typst markup |
| `inputs` | values the document reads as `inputs`, e.g. `#inputs.n` |
| `editable` | a text box above the output, re-rendered as you type |
| `controls` | sliders drawn by the widget that write into `inputs`, e.g. `{"n": {"min": 1, "max": 10}}` |
| `error` | the latest compile error, or `""`, set by the browser |

Setting `inputs` on an existing widget (`doc.widget.inputs = {...}`)
re-renders it without rebuilding it, so text typed in its editor is kept.

## Where it works

The compiler runs in the browser, so Python never runs Typst.

| Where | marimo controls (`mo.ui.*`) | `controls` | Python |
| --- | --- | --- | --- |
| `marimo edit` / `marimo run` | yes | yes | yes |
| WASM export (`marimo export html-wasm`) | yes | yes | Pyodide |
| Static export (`marimo export html`) | no: a snapshot at export time | yes | only inside the document, with `@preview/pyrunner` |

For a WASM export the package has to be installable from PyPI, because the
export doesn't include local files. It isn't published yet.

## Things to know

- On first use the browser downloads the compiler (28 MB) and fonts from
  jsDelivr, once per page. It doesn't work offline unless you host them.
- Typst Universe packages (`#import "@preview/..."`) are downloaded by the
  browser too.
- `@preview/pyrunner` runs Python inside the document with RustPython:
  standard library only, no file or network access, and an 11 MB plugin.
- Multi-page documents are drawn one page below the other.
- marimo puts each anywidget in its own shadow DOM, so the styles typst.ts
  adds to its SVG don't reach the rest of the notebook.

## Examples

```sh
pip install -e '.[dev]'
marimo edit examples/demo.py       # marimo slider + live editor
marimo edit examples/features.py   # packages, multi-page, updating inputs
marimo export html examples/pyrunner.py -o pyrunner.html   # interactive with no kernel
```
