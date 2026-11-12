import marimo

app = marimo.App()


@app.cell
def _():
    import marimo as mo
    from typst_widget import Typst
    return Typst, mo


@app.cell
def _(mo):
    n = mo.ui.slider(1, 10, value=3, label="n")
    n
    return (n,)


@app.cell
def _(Typst, mo, n):
    doc = mo.ui.anywidget(
        Typst(
            "#set page(width: auto, height: auto, margin: 8pt)\n"
            "= Hello from Typst\n"
            "$ sum_(i=1)^(#inputs.n) i^2 = #(range(1, inputs.n + 1).map(i => i * i).sum()) $",
            inputs={"n": n.value},
            editable=True,
        )
    )
    doc
    return (doc,)


@app.cell
def _(doc):
    doc.value.get("error") or "compiled OK"
    return


if __name__ == "__main__":
    app.run()
