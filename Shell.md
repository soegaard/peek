# Shell Design Notes

## Source Of Truth

The shell previewers use `lexers/shell` as their source of truth.

The first pass covers three explicit preview targets:

- `bash`
- `zsh`
- `powershell`

These are mapped from the file extensions:

- `.sh` and `.bash` -> `bash`
- `.zsh` -> `zsh`
- `.ps1` -> `powershell`

## Rendering Model

The shell previewers are color-only and terminal-first.

`peek` colors shell comments, keywords, builtins, variables, command
substitutions, punctuation, and malformed input, while preserving source text
and line breaks. The previewers do not add alignment, wrapping, or shell-
specific layout transforms.

The shell support is intended to stay source-faithful after ANSI stripping so
the same round-trip tests used for the other file types can catch regressions
in the lexer or renderer.

## Streaming Use

Shell preview uses the port-oriented streaming path.

That means large shell scripts and stdin input can be previewed without first
materializing the whole source as a string.
