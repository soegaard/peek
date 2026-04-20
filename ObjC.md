# Objective-C

The Objective-C previewer uses `lexers/objc` as its source of truth.

It should stay terminal-first, preserve source text after ANSI stripping, and
keep malformed input visible rather than crashing.

Use the derived-token API from `lexers/objc` as the primary semantic input.
That keeps comments, `@`-keywords, literals, identifiers, operators, and
preprocessor directives visually distinct without reimplementing Objective-C
lexing locally.

The first-pass file-type support maps `.m` files to the `objc` previewer.
Markdown fenced code blocks labeled `objc`, `objective-c`, `objectivec`, or
`obj-c` should also delegate to `lexers/objc`.

The current styling should color:

- comments
- `@`-keywords
- literals
- identifiers
- operators and delimiters
- malformed input

Keep Objective-C source-faithful after ANSI stripping, and let `lexers/objc`
drive future improvements.
