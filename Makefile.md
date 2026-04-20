# Makefile

The Makefile previewer uses `lexers/makefile` as its source of truth.

It should stay terminal-first, preserve source text after ANSI stripping, and
keep malformed input visible rather than crashing.

Use the derived-token API from `lexers/makefile` as the primary semantic
input. That keeps directives, assignments, rule targets, variable references,
and recipe lines visually distinct without reimplementing Makefile lexing
locally.

The first-pass file-type support maps ordinary `Makefile`, `GNUmakefile`, and
`.mk` files to the `makefile` previewer. Markdown fenced code blocks labeled
`make`, `makefile`, or `mk` should also delegate to `lexers/makefile`.

The current styling should color:

- comments
- directives
- rule targets and variable names
- variable references
- assignment operators and delimiters
- malformed input

Keep Makefile source-faithful after ANSI stripping, and let
`lexers/makefile` drive future improvements.
