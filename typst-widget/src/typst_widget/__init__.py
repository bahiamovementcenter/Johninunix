"""Typst documents in marimo (or any anywidget host), compiled in the browser.

The browser compiles the Typst source with typst.ts (Typst built for
WebAssembly), so Python never runs the Typst compiler. That means the widget
also works in static HTML exports and in marimo's WASM notebooks.
"""

import pathlib

import anywidget
import traitlets

__all__ = ["Typst"]


class Typst(anywidget.AnyWidget):
    """A Typst document.

    source:   the Typst markup.
    inputs:   values the document reads as `inputs`, e.g. `#inputs.n`.
    editable: show a text box above the output to edit the source live.
    controls: sliders drawn in the browser that write into `inputs`, e.g.
              {"n": {"min": 1, "max": 10, "step": 1}}. They work without a
              Python kernel, so they still work in a static HTML export.
    error:    the latest compile error, or "" (set by the browser).
    """

    _esm = pathlib.Path(__file__).parent / "widget.js"

    source = traitlets.Unicode("").tag(sync=True)
    inputs = traitlets.Dict({}).tag(sync=True)
    editable = traitlets.Bool(False).tag(sync=True)
    controls = traitlets.Dict({}).tag(sync=True)
    error = traitlets.Unicode("").tag(sync=True)

    def __init__(self, source: str = "", **kwargs):
        super().__init__(source=source, **kwargs)
