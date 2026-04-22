# TeX

`peek` treats TeX as a color-only terminal preview target built on
`lexers/tex`.

The current first pass aims to stay source-faithful after ANSI stripping. It
highlights TeX comments, control words, control symbols, math shifts,
accent commands, spacing commands, parameters, and structural delimiters
while leaving ordinary text readable and unstyled.

TeX preview support currently covers explicit `tex` previews and `.tex`
inputs. It also participates in fenced Markdown delegation when the Markdown
lexer exposes `embedded-tex`.
