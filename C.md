# C Design Notes

The C previewer uses `lexers/c` as its source of truth.

The first pass targets ordinary C source in `.c` files, plus headers in `.h`
files.

The C previewer is intentionally color-only. It preserves source text and line
breaks without layout rewriting.

`peek` colors C preprocessor directives, keywords, strings, character literals,
identifiers, delimiters, operators, and malformed input with best-effort
recovery.

C preview uses the port-oriented streaming path.

That means large C files and stdin input can be previewed without first
materializing the whole source as a string.
