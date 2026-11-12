import marimo

app = marimo.App()


@app.cell
def _():
    import marimo as mo
    from typst_widget import Typst
    return Typst, mo


@app.cell
def _(Typst, mo):
    # Python runs inside the Typst document (@preview/pyrunner, RustPython,
    # standard library only), and the slider is drawn by the widget itself.
    # Neither needs a Python kernel, so this stays interactive in a static
    # HTML export (`marimo export html examples/pyrunner.py`).
    src = r"""#set page(width: auto, height: auto, margin: 8pt)
#import "@preview/pyrunner:0.3.0" as py
#let code = ```
import math
primes = [p for p in range(2, n + 1) if all(p % d for d in range(2, math.isqrt(p) + 1))]
f"primes up to {n}: {primes} (count {len(primes)})"
```
= pyrunner inside Typst
#py.block(code, globals: (n: int(inputs.n)))
"""
    doc = mo.ui.anywidget(
        Typst(src, inputs={"n": 10}, controls={"n": {"min": 2, "max": 60, "step": 1}})
    )
    doc
    return (doc,)


if __name__ == "__main__":
    app.run()
