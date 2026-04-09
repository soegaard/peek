# `peek` HTML Notes

## Purpose

These notes describe how `peek` should render HTML when HTML support is added.

The HTML previewer should use `lexers/html` as its source of truth for
tokenization and reusable language-level classification. It should not
introduce a separate HTML tokenizer inside `peek`.

## Lexer Direction

Use the derived-token API from `lexers/html` as the primary semantic input.

The intended rendering rule is:

- color from derived tags first
- fall back to projected token categories second

This keeps the renderer simple while allowing future improvements in
`lexers/html` to improve `peek` automatically.

## First-Pass Role Mapping

The initial HTML renderer should use a small terminal-oriented role mapping.

- `html-tag-name`
- `html-closing-tag-name`
- `html-doctype`
  - render with the tag or keyword color
- `html-attribute-name`
  - render with the name color
- `html-attribute-value`
- `html-entity`
  - render with the value color
- `html-text`
  - render as plain text
- `comment`
  - render with the comment color
- `malformed-token`
  - render with a distinct error style

Projected delimiter and operator categories should supply punctuation styling
where the derived-token layer does not provide a more specific role.

## Embedded Languages

When `lexers/html` reports embedded tokens inside `<style>` and `<script>`
bodies, `peek` should reuse the existing CSS and JavaScript color model.

For the first HTML pass:

- embedded CSS should reuse CSS-oriented color semantics
- embedded JavaScript should reuse JavaScript-oriented color semantics
- the HTML previewer should not add HTML-specific layout transforms inside
  embedded regions

In particular, first-pass HTML support is color-only at the HTML layer.
It should not introduce:

- HTML-specific swatches
- HTML-specific alignment
- CSS swatches or alignment inside embedded `<style>` regions

## Consumer Boundary

`lexers/html` should answer:

- what token text and positions exist
- what reusable HTML role a token has
- when delegated embedded CSS and JavaScript tokens occur

`peek` should answer:

- how those roles are styled in the terminal
- how embedded CSS and JavaScript styling is reused
- any terminal-specific presentation choices
