# Swift Design Notes

## Source Of Truth

The Swift previewer uses `lexers/swift` as its source of truth.

`peek` exposes the explicit file type name `swift` for standalone Swift
sources.

## Rendering Model

The first Swift pass is syntax coloring only.

`peek` does not try to interpret Swift as a build system, package manifest, or
project configuration. Ordinary source text stays source text; the previewer
only adds ANSI color for useful lexical roles.

## Supported Files

Swift preview currently targets `.swift` files.

## Embedded Swift

Markdown fenced code blocks labeled `swift` delegate to `lexers/swift`.
`peek` should reuse the same Swift style mapping for those delegated regions so
the embedded preview stays consistent with standalone `.swift` files.
