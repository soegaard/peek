# Go Design Notes

The Go previewer uses `lexers/go` as its source of truth.

The first pass targets ordinary Go source in `.go` files, plus common Go
module files such as `go.mod` and `go.work`.

The Go previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors Go comments, keywords, identifiers, literals, operators,
delimiters, and malformed input with best-effort recovery.

Go preview uses the port-oriented streaming path.

That means large Go files and stdin input can be previewed without first
materializing the whole source as a string.
