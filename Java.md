# `peek` Java Notes

## Purpose

These notes describe how `peek` should render Java when Java support is
present.

The Java previewer should use `lexers/java` as its source of truth for
tokenization and reusable Java-specific classification. It should not
introduce a separate Java tokenizer inside `peek`.

## Lexer Direction

Use the derived-token API from `lexers/java` as the primary semantic input.

The intended rendering rule is:

- color from derived tags first
- fall back to projected token categories second

This keeps the renderer simple while allowing future improvements in
`lexers/java` to improve `peek` automatically.

## First-Pass Role Mapping

The first Java renderer should stay terminal-oriented and color-only.

- `java-keyword`
  - render with the keyword color
- `java-annotation-name`
  - render with a keyword-like color so annotations remain visible
- `java-line-comment`
- `java-block-comment`
- `java-doc-comment`
  - render with the comment color
- `java-string-literal`
- `java-text-block`
- `java-char-literal`
- `java-numeric-literal`
- `java-boolean-literal`
- `java-true-literal`
- `java-false-literal`
- `java-null-literal`
  - render with the value color
- `java-identifier` without a more specific semantic tag
  - render with the plain identifier/name style
- `java-annotation-marker`
- `java-delimiter`
- `java-operator`
  - render with punctuation styling
- `malformed-token`
  - render with a distinct error style

## Scope Boundaries

The first Java previewer in `peek` should stay intentionally small.

Included in the first pass:

- syntax coloring from `lexers/java`
- support for reusable Java derived tags
- support for embedded Java inside Markdown fenced code blocks

Out of scope for the first pass:

- Java semantic navigation
- documentation-link inference
- framework-specific heuristics
- custom tokenization inside `peek`

## Consumer Boundary

`lexers/java` should answer:

- what token text and positions exist
- what reusable Java role a token has

`peek` should answer:

- how those roles are styled in the terminal
- whether file detection enables Java mode
- any terminal-specific layout or presentation choices
