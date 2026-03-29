# `peek` JavaScript Notes

## Purpose

These notes describe how `peek` should render JavaScript and JSX when
JavaScript support is added.

The JavaScript previewer should use `lexers/javascript` as its source of truth
for tokenization and reusable language-level classification. It should not
introduce a separate JavaScript or JSX tokenizer inside `peek`.

## Lexer Direction

Use the derived-token API from `lexers/javascript` as the primary semantic
input.

The intended rendering rule is:

- color from derived tags first
- fall back to projected token categories second

This keeps the renderer simple while allowing future improvements in
`lexers/javascript` to improve `peek` automatically.

For JSX input, the JavaScript previewer should enable `#:jsx? #t` when the
selected file type or detection rules indicate JSX-bearing JavaScript.

## First-Pass Role Mapping

The initial JavaScript renderer should use a small terminal-oriented role
mapping.

### JavaScript

- `keyword` and `static-keyword-usage`
  - render with the keyword color
- `declaration-name`
- `parameter-name`
- `property-name`
- `method-name`
- `private-name`
- `object-key`
  - render with the name color
- `string-literal`
- `numeric-literal`
- `regex-literal`
- `template-literal`
- `template-chunk`
  - render with the value color
- `identifier` without a more specific semantic tag
  - render with the plain identifier/name style
- `comment`
  - render with the comment color
- `malformed-token`
  - render with a distinct error style

Projected categories such as delimiter/operator should supply punctuation
styling where the derived-token layer does not provide a more specific role.

### JSX

- `jsx-tag-name`
- `jsx-closing-tag-name`
  - render with a tag-oriented or keyword-like color
- `jsx-attribute-name`
  - render with the name color
- `jsx-text`
  - render with plain text or a value-adjacent style
- `jsx-interpolation-boundary`
- `jsx-fragment-boundary`
  - render with punctuation styling

JSX should be treated as JavaScript with extra structural roles, not as a
separate HTML theme.

## Scope Boundaries

The first JavaScript previewer in `peek` should stay intentionally small.

Included in the first pass:

- syntax coloring from `lexers/javascript`
- support for reusable JavaScript derived tags
- support for reusable JSX derived tags when `#:jsx?` is enabled

Out of scope for the first pass:

- MDN-style documentation-link inference
- React-specific or framework-specific heuristics
- component-name heuristics beyond what `lexers/javascript` already exposes
- preview widgets for regexes or template literals
- custom tokenization inside `peek`

## Consumer Boundary

`lexers/javascript` should answer:

- what token text and positions exist
- what reusable language role a token has

`peek` should answer:

- how those roles are styled in the terminal
- whether file detection enables JSX mode
- any terminal-specific layout or presentation choices
