# `peek` Scribble Notes

## Purpose

These notes describe how `peek` should render Scribble when Scribble support
is added.

The Scribble previewer should use `lexers/scribble` as its source of truth for
tokenization and reusable language-level classification. It should not
introduce a separate Scribble tokenizer inside `peek`.

## Lexer Direction

Use the derived-token API from `lexers/scribble` as the primary semantic
input.

The intended rendering rule is:

- color from derived tags first
- fall back to projected token categories second

This keeps the renderer simple while allowing future improvements in
`lexers/scribble` to improve `peek` automatically.

## First-Pass Role Mapping

The initial Scribble renderer should use a small terminal-oriented role
mapping.

- `scribble-command-char`
  - render with delimiter or punctuation styling
- `scribble-command`
  - render with the keyword color
- `scribble-body-delimiter`
- `scribble-optional-delimiter`
- `scribble-parenthesis`
  - render with delimiter styling
- `scribble-text`
  - render as plain text
- `scribble-string`
- `scribble-constant`
  - render with the value color
- `scribble-symbol`
- `scribble-other`
  - render with the identifier or name color
- `scribble-comment`
  - render with the comment color
- `scribble-error`
  - render with a distinct error style

## Embedded Racket

When `lexers/scribble` marks a token with `scribble-racket-escape`, `peek`
should reuse the Racket terminal color model for that token.

The current Scribble lexer exposes the embedded-region marker, but it does not
expose the full `lexers/racket` derived-tag set for those tokens. So the first
pass should reuse the Racket color model at the style level, based on the
token's projected category and Scribble-side tags, without trying to add a
separate local Racket analysis pass.

## Scope Boundaries

The first Scribble previewer in `peek` should stay intentionally small.

Included in the first pass:

- syntax coloring from `lexers/scribble`
- support for reusable Scribble derived tags
- coloring of embedded Racket escapes
- best-effort previewing in coloring mode

Out of scope for the first pass:

- document-style or prose-aware terminal layout
- structure-aware formatting
- alias support such as `--type scribble`

## Consumer Boundary

`lexers/scribble` should answer:

- what token text and positions exist
- what reusable Scribble role a token has
- which tokens occur inside Scribble Racket escapes

`peek` should answer:

- how those roles are styled in the terminal
- that `.scrbl` maps to the Scribble previewer
- that `--type scrbl` selects the Scribble previewer for stdin
