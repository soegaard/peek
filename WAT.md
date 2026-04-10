# WAT Design Notes

## Source Of Truth

The WAT previewer uses `lexers/wat` as its source of truth.

The first pass targets WebAssembly text format in `.wat` files only. `peek`
does not support binary `.wasm` files, and it does not treat `.wast` as an
alias in this pass.

## Rendering Model

The first WAT pass is syntax coloring only.

`peek` colors forms, types, and instructions as keyword-like syntax; `$`
identifiers as identifiers; strings and numeric literals as literals; comments
as comments; and parentheses as delimiters.

The previewer does not currently add indentation normalization, alignment, or
other WAT-specific layout transforms.

## Embedded Markdown Use

`lexers/markdown` can delegate fenced `wat` blocks.

When Markdown tokens carry `embedded-wat`, `peek` should reuse the same WAT
style mapping used by standalone `.wat` files. Markdown should not parse fence
info strings or classify WAT syntax locally.
