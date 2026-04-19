# Python Design Notes

The Python previewer uses `lexers/python` as its source of truth.

The first pass targets ordinary Python source in `.py` files, plus the common
variants `.pyi` and `.pyw`.

The Python previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors Python comments, keywords, literals, identifiers, delimiters,
operators, and malformed input with best-effort recovery.

Python preview uses the port-oriented streaming path.

That means large Python files and stdin input can be previewed without first
materializing the whole source as a string.
