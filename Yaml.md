# YAML Design Notes

The YAML previewer uses `lexers/yaml` as its source of truth.

The first pass targets ordinary YAML source in `.yaml` files, plus shorter
`.yml` files.

The YAML previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors YAML keys, scalars, anchors, tags, aliases, delimiters, and
malformed input with best-effort recovery.

YAML preview uses the port-oriented streaming path.

That means large YAML files and stdin input can be previewed without first
materializing the whole source as a string.
