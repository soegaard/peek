# LaTeX

`peek` treats LaTeX as a color-only terminal preview target built on
`lexers/latex`.

The current first pass keeps the renderer source-faithful after ANSI
stripping. It highlights common LaTeX commands such as `\section`,
`\begin`, and `\end`, plus environment names, `\verb` spans, and line-break
commands, while leaving ordinary text readable and unstyled.

LaTeX preview support currently covers explicit `latex` previews plus common
LaTeX-oriented inputs such as `.cls`, `.sty`, `.latex`, and `.ltx` files. It
also participates in fenced Markdown delegation when the Markdown lexer
exposes `embedded-latex`.
