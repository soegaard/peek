# JSON Design Notes

The JSON previewer uses `lexers/json` as its source of truth.

The first pass targets ordinary JSON source in `.json` files, plus related
JSON-formatted manifests such as `.webmanifest` files.

The JSON previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors JSON object keys, strings, numbers, booleans, null, delimiters,
and malformed input with best-effort recovery.

JSON preview uses the port-oriented streaming path.

That means large JSON files and stdin input can be previewed without first
materializing the whole source as a string.
