# Rhombus Design Notes

## Source Of Truth

The Rhombus previewer uses `lexers/rhombus` as its source of truth.

The first pass targets Rhombus source files in `.rhm` files.

## Rendering Model

The first Rhombus pass is syntax coloring only.

`peek` colors Rhombus comments, keywords, builtins, identifiers, literals,
operators, delimiters, and malformed input while preserving source text and
line breaks.

The previewer does not add indentation normalization, alignment, or other
Rhombus-specific layout transforms.

## Streaming Use

Rhombus preview uses the port-oriented streaming path.

That means large Rhombus files and stdin input can be previewed without first
materializing the whole source as a string.
