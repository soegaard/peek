# Rust Design Notes

The Rust previewer uses `lexers/rust` as its source of truth.

The first pass targets ordinary Rust source in `.rs` files.

The Rust previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors Rust comments, keywords, literals, identifiers, delimiters,
operators, and malformed input with best-effort recovery.

Rust preview uses the port-oriented streaming path.

That means large Rust files and stdin input can be previewed without first
materializing the whole source as a string.
