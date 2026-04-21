# Pascal Design Notes

The Pascal previewer uses `lexers/pascal` as its source of truth.

The first pass targets ordinary Pascal source in `.pas`, `.pp`, `.dpr`, `.lpr`,
and `.inc` files.

The Pascal previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors Pascal comments, keywords, literals, identifiers, delimiters,
operators, and malformed input with best-effort recovery.

Pascal preview uses the port-oriented streaming path.

That means large Pascal files and stdin input can be previewed without first
materializing the whole source as a string.
