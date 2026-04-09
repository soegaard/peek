# `peek` Racket Notes

## Purpose

These notes describe how `peek` should render Racket when Racket support is
added.

The Racket previewer should use `lexers/racket` as its source of truth for
tokenization and reusable language-level classification. It should not
introduce a separate Racket tokenizer inside `peek`.

## Lexer Direction

Use the derived-token API from `lexers/racket` as the primary semantic input.

The intended rendering rule is:

- color from derived tags first
- fall back to projected token categories second

This keeps the renderer simple while allowing future improvements in
`lexers/racket` to improve `peek` automatically.

## First-Pass Role Mapping

The initial Racket renderer should use a small terminal-oriented role mapping.

- `racket-comment`
- `racket-sexp-comment`
- `racket-commented-out`
  - render with the comment color
- `racket-string`
- `racket-constant`
- `racket-hash-colon-keyword`
  - render with the value color
- `racket-parenthesis`
- `racket-open`
- `racket-close`
- `racket-continue`
  - render with delimiter styling
- `racket-usual-special-form`
- `racket-definition-form`
- `racket-binding-form`
- `racket-conditional-form`
  - render with the keyword color
- `racket-symbol`
- `racket-datum`
  - render with the identifier or name color
- `racket-error`
  - render with a distinct error style

Whitespace should remain unstyled, and the first pass should keep `#lang`
lines, symbols, and identifiers within the existing generic color model.

The form tags are heuristic. They are useful for previewing common built-in
forms such as `define`, `if`, and `let`, but they are not binding-aware.

## Scope Boundaries

The first Racket previewer in `peek` should stay intentionally small.

Included in the first pass:

- syntax coloring from `lexers/racket`
- support for reusable Racket derived tags
- best-effort previewing in coloring mode
- file detection for `.rkt`, `.ss`, `.scm`, and `.rktd`

Out of scope for the first pass:

- structure-aware formatting
- alignment
- swatches
- binding analysis
- `.scrbl` support
- `.rktl` support

## Consumer Boundary

`lexers/racket` should answer:

- what token text and positions exist
- what reusable Racket role a token has

`peek` should answer:

- how those roles are styled in the terminal
- that `.rkt`, `.ss`, `.scm`, and `.rktd` map to the Racket previewer
- that `--type rkt` selects the Racket previewer for stdin
