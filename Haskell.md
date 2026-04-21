# Haskell Design Notes

The Haskell previewer uses `lexers/haskell` as its source of truth.

The first pass targets ordinary Haskell source in `.hs` and `.lhs` files,
with boot files such as `.hs-boot` and `.lhs-boot` treated as Haskell too.

The Haskell previewer is intentionally color-only. It preserves source text and
line breaks without layout rewriting.

`peek` colors Haskell comments, pragmas, keywords, identifiers, literals,
operators, delimiters, and malformed input with best-effort recovery.

Haskell preview uses the port-oriented streaming path.

That means large Haskell files and stdin input can be previewed without first
materializing the whole source as a string.
