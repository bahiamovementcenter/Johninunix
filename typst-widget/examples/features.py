import marimo

app = marimo.App()


@app.cell
def _():
    import marimo as mo
    from typst_widget import Typst
    return Typst, mo


@app.cell
def _(Typst, mo):
    # Typst Universe packages are downloaded by the browser on first use.
    pkg = mo.ui.anywidget(
        Typst(
            "#set page(width: auto, height: auto, margin: 8pt)\n"
            '#import "@preview/cetz:0.3.4"\n'
            "#cetz.canvas({ import cetz.draw: *; circle((0,0), radius: 1); line((0,0),(1,0)) })"
        )
    )
    pkg
    return (pkg,)


@app.cell
def _(Typst, mo):
    # Every page is drawn, one below the other.
    multi = mo.ui.anywidget(
        Typst(
            "#set page(width: 6cm, height: 3cm)\n"
            "Page one\n#pagebreak()\nPage two\n#pagebreak()\nPage three"
        )
    )
    multi
    return (multi,)


@app.cell
def _(Typst, mo):
    live = mo.ui.anywidget(
        Typst(
            "#set page(width: auto, height: auto, margin: 8pt)\n"
            'n is #inputs.at("n", default: "unset")',
            editable=True,
        )
    )
    live
    return (live,)


@app.cell
def _(live, mo):
    # Setting `inputs` on the existing widget re-renders it without
    # rebuilding it, so text typed in its editor is kept.
    bump = mo.ui.button(
        label="set n=42",
        on_click=lambda _: setattr(live.widget, "inputs", {"n": 42}),
    )
    bump
    return


@app.cell
def _(multi, pkg):
    {"pkg_error": pkg.value.get("error"), "multi_error": multi.value.get("error")}
    return


if __name__ == "__main__":
    app.run()
