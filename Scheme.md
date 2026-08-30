# Scheme Preview

Scheme preview uses `lexers/scheme` for source-preserving, streaming terminal
coloring. The default dialect is R5RS.

Automatic detection is limited to `.sld` library files. Existing `.scm` and
`.ss` routing remains with the Racket previewer; users can select Scheme
coloring explicitly with `peek --type scheme file.scm`.

The corpus round-trip test selects its lexer dialect from the top-level corpus
directory, covering R5RS, R6RS, R7RS, Chez, Guile, Chicken, and Gambit.
