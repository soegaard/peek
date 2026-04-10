# CSS Design Notes

## CSS As The First Supported File Type

CSS is the first supported file type.

The CSS previewer must use `lexers/css` for lexing. `peek` should not implement
its own CSS lexer. File-type-specific rendering may build additional structure
on top of lexer tokens, but `lexers/css` remains the source of truth for token
categories and source positions.

For CSS, the terminal preview supports:

- ANSI syntax coloring
- Optional swatches for color literals, supported color functions, gradients,
  and resolvable custom-property colors
- Optional intra-rule alignment
- Best-effort output on malformed input

## CSS Rendering Model

The CSS previewer has three internal stages:

1. Lexing adapter
   - consume tokens from `lexers/css`
   - normalize them into a representation suitable for rendering
   - preserve useful token metadata, especially category and source position

2. CSS post-processing
   - identify declaration structure where needed
   - recognize renderable color values
   - resolve custom-property color references when practical
   - compute alignment information when requested

3. Terminal rendering
   - emit ANSI-colored text
   - insert swatches unless disabled
   - apply optional intra-rule alignment
   - preserve source text as much as possible unless an explicit layout option
     changes it

## Streaming Considerations

Basic CSS token coloring can be streamed from `lexers/css`, but the current
high-quality CSS preview in `peek` is not just a token-to-color pass.

The existing CSS renderer depends on buffered, cross-token decisions such as:

- swatch insertion
- intra-rule and cross-rule alignment
- decimal and unit alignment
- repeated-function argument alignment
- custom-property-aware value rendering

CSS custom properties and `var(...)` usage are part of why this matters.
Variable names participate in alignment columns, fallback values may contain
colors, functions, and numbers, and inserted visible elements such as swatches
change rendered width.

That means a future streaming CSS path should be treated as a separate
trade-off:

- a streaming color-only path could be appropriate for very large CSS inputs
- the current polished CSS preview should remain buffered while it depends on
  rendered-width-aware layout decisions across multiple declarations or rules

The file
[`css-highlight-new35.rkt`](/Users/soegaard/Downloads/css-highlight-new35.rkt)
is useful prior art for rendering ideas such as swatches and alignment, but not
for tokenization, since `peek` must use `lexers/css`.

## Swatches And Alignment

Swatches are part of the rendered output, so alignment must be based on
rendered width, not just source-token text width.

That means CSS rendering follows this internal pipeline:

1. Build a render-oriented stream from the CSS lexer output.
2. Insert synthetic render items for visible additions such as swatches.
3. Measure display width from the render-oriented stream.
4. Apply alignment using those rendered widths.
5. Emit ANSI-colored terminal text.

This ordering matters because inserted swatches change the visible width of a
declaration. If alignment were computed before swatch insertion, later
declarations could drift out of alignment in the final terminal output.

For implementation purposes, alignment should operate on render items with a
defined display width, not directly on raw lexer tokens. ANSI escape sequences
have width 0, ordinary text contributes its visible character width, and each
swatch contributes its rendered terminal width. When `--no-swatches` is used,
the swatch render items are omitted and alignment is recomputed from the
remaining rendered output.

### Cross-rule Alignment

For CSS, cross-rule alignment is acceptable for simple sibling rule groups when
it improves scanability.

The intended rules are:

1. Align selectors across sibling single-line rules so their `{` tokens land in
   the same column.
2. Align matching property columns across those same sibling rules.
3. Compute cross-rule alignment from rendered width, including any visible
   swatches.
4. Only apply cross-rule alignment when the participating rules have the same
   ordered property set.
5. When repeated aligned lines use the same function call shape, such as
   repeated `rgba(...)` values, align the function arguments when doing so
   improves scanability.

This is a CSS-specific formatting rule. It should not be treated as a generic
preview rule for other file types.

## CSS CLI Direction

For CSS, the relevant options are:

- `--type css`
- `--align`
- `--no-swatches`
- `--color always|auto|never`

Defaults:

- CSS preview uses syntax coloring by default
- color mode defaults to `always`
- non-interactive output stays colored unless color mode is changed explicitly
- swatches are enabled by default
- `--no-swatches` disables swatch rendering only
- `--align` enables intra-rule alignment only

## CSS Scope Boundaries For v1

Included in v1:

- CSS syntax coloring via `lexers/css`
- CSS swatches
- CSS intra-rule alignment
- tests with realistic CSS samples

Excluded from v1:

- custom CSS lexing
- cross-rule alignment

## CSS Testing

Tests should use `rackunit` and cover:

- realistic CSS syntax-coloring cases
- malformed CSS with best-effort output
- swatch rendering and `--no-swatches`
- intra-rule alignment
