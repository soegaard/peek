# Delimited Text Design Notes

The CSV and TSV previewers use `lexers/csv` and `lexers/tsv` as their source
of truth.

The first pass targets ordinary `.csv` and `.tsv` files.

The delimited-text previewers are intentionally color-only. They preserve
source text and line breaks without layout rewriting.

`peek` colors CSV/TSV headers, scalars, separators, and malformed input with
best-effort recovery.

Delimited-text preview uses the port-oriented streaming path.

That means large CSV and TSV files and stdin input can be previewed without
first materializing the whole source as a string.
