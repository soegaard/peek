# peek

This terminal-first preview tool shows files and standard input in the
terminal.
Its goal is to keep source readable without trying to replace a pager or a
full editor.

## Install

The package is distributed as a Racket package, and installing it makes the
`peek` launcher available on the command line.

```sh
raco pkg install peek
```

## Quick Start

Preview a file directly. By default, `peek` opens the rendered output in a
pager:

```sh
peek path/to/file.css
peek path/to/folder/
peek path/to/archive.zip
peek path/to/file.bin
peek path/to/file.c
peek path/to/file.cpp
peek path/to/file.m
peek Makefile
peek GNUmakefile
peek path/to/file.mk
peek path/to/file.csv
peek path/to/file.sh
peek path/to/file.html
peek path/to/file.go
peek path/to/file.java
peek path/to/file.hs
peek path/to/file.js
peek path/to/file.json
peek path/to/file.tex
peek path/to/file.cls
peek path/to/file.sty
peek path/to/file.plist
peek path/to/file.yaml
peek path/to/file.py
peek path/to/file.pas
peek path/to/file.rs
peek path/to/file.swift
peek path/to/file.md
peek path/to/file.rhm
peek path/to/file.rkt
peek path/to/file.ss
peek path/to/file.scrbl
peek path/to/file.wat
```

Preview from standard input by choosing a file type explicitly:

```sh
cat path/to/file.md | peek --type md
cat path/to/archive.tar | peek --type archive
cat path/to/file.bin | peek --type binary
cat path/to/file.bin | peek --type binary --bits
cat path/to/file.bin | peek --type binary --search-bytes 4243 --search-bytes C4
cat path/to/file.bin | peek --type binary --search-text peek
cat path/to/file.c | peek --type c
cat path/to/file.cpp | peek --type cpp
cat path/to/file.m | peek --type objc
cat path/to/file.mk | peek --type makefile
cat path/to/file.csv | peek --type csv
cat path/to/file.go | peek --type go
cat path/to/file.java | peek --type java
cat path/to/file.rhm | peek --type rhombus
cat path/to/file.hs | peek --type haskell
cat path/to/file.json | peek --type json
cat path/to/file.tex | peek --type tex
cat path/to/file.cls | peek --type latex
cat path/to/file.sty | peek --type latex
cat path/to/file.plist | peek --type plist
cat path/to/file.yaml | peek --type yaml
cat path/to/file.py | peek --type python
cat path/to/file.swift | peek --type swift
cat path/to/file.rkt | peek --type rkt
cat path/to/file.ss | peek --type rkt
cat path/to/file.wat | peek --type wat
cat path/to/script.sh | peek --type bash
```

List the currently supported explicit file types:

```sh
peek --list-file-types
```

Write output directly to the terminal instead of using the default pager:

```sh
peek -P path/to/file.css
```

Enable pretty rendering when a previewer supports it:

```sh
peek -p path/to/file.md
```

Add nl-style line numbers:

```sh
peek -n -P path/to/file.rkt
```

Emphasize rendered lines whose text matches a regexp:

```sh
peek --grep TODO -P path/to/file.rkt
```

Preview only the changed Git hunks for one file:

```sh
peek --diff path/to/file.rkt
peek -n --diff path/to/file.rkt
```

Diff preview shows context lines with a leading two-space marker, removed
lines with `- `, and added lines with `+ `. When line numbers are enabled,
context and added lines use the current-file line numbers, while removed lines
use the old-file line numbers from Git.

Preview one Markdown section by heading title:

```sh
peek --section "Demo Document" -P path/to/file.md
```

## Examples

A few small previews, rendered by `peek`:

| CSS | HTML |
| --- | --- |
| ![CSS preview](assets/screenshots/example-css.png) | ![HTML preview](assets/screenshots/example-html.png) |

| Racket | WAT |
| --- | --- |
| ![Racket preview](assets/screenshots/example-racket.png) | ![WAT preview](assets/screenshots/example-wat.png) |

If you want to regenerate a window screenshot, `tools/capture-peek-window.sh`
opens Terminal, runs `peek`, and captures the window as a PNG.

## Supported File Types

Current supported file types are:

- `css`
- `archive`
- `binary`
- `c`
- `cpp`
- `objc`
- `bash`
- `makefile`
- `html`
- `go`
- `java`
- `haskell`
- `js`
- `json`
- `jsx`
- `latex`
- `md`
- `plist`
- `pascal`
- `powershell`
- `python`
- `rhombus`
- `rkt`
- `rust`
- `scrbl`
- `swift`
- `tex`
- `csv`
- `tsv`
- `wat`
- `yaml`
- `zsh`

CSS supports syntax coloring, swatches, and optional alignment. The other
current file types are color-focused terminal previews. C uses the `c`
previewer and preserves source text and line breaks without layout rewriting.
C++ uses the `cpp` previewer and preserves source text and line breaks without
layout rewriting. Objective-C uses the `objc` previewer and preserves source
text and line breaks without layout rewriting. Makefiles use the `makefile`
previewer; recipe bodies are shell-aware while preserving Makefile variable
references, source text, and line breaks without layout rewriting. Rust uses
the `rust` previewer and preserves source text and line breaks without layout
rewriting. CSV and TSV use the `csv` and
`tsv` previewers and preserve source text and line breaks without layout
rewriting. JSON uses the `json` previewer and preserves source text and line
breaks without layout rewriting. Go uses the `go` previewer and preserves
source text and line breaks without layout rewriting. Java uses the `java`
previewer and preserves source text and line breaks without layout rewriting.
Haskell uses the
`haskell` previewer and preserves source text and line breaks without layout
rewriting. Plist uses the `plist` previewer and preserves source text and
line breaks without layout rewriting. Pascal uses
the `pascal` previewer and preserves source text and line breaks without
layout rewriting. Python uses the `python` previewer and preserves source text
and line breaks without layout rewriting. Rhombus uses the `rhombus`
previewer and preserves source text and line breaks without layout rewriting.
Shell files use the `bash`, `zsh`, and `powershell` previewers and preserve
source text and line breaks without layout rewriting. Swift uses the `swift`
previewer and preserves source text and line breaks without layout rewriting.
YAML uses the `yaml` previewer and preserves source text and line breaks
without layout rewriting.
Directory paths use the directory previewer and show a flat listing with
directories first, simple kind-aware coloring, right-aligned file sizes, and
optional `--kind` / `--size` sorting. Directory preview is selected from the
path itself, not with `--type`.
TeX uses the `tex` previewer and preserves source text and line breaks
without layout rewriting, while giving math shifts, accent commands, spacing
commands, parameters, and delimiters their own terminal structure. LaTeX
uses the `latex` previewer and preserves source text and line breaks without
layout rewriting, while also keeping environment names, `\verb` spans, and
line-break commands readable.
Racket-family files use the `racket` previewer and preserve source text and
line breaks without layout rewriting. A bundled standard-vocabulary map helps
exact forms and builtins stand out from local identifiers, while a small
heuristic keeps form-like and binding-form-like names readable.
Archive files use the `archive` previewer and show a directory tree for
supported formats such as ZIP, TAR, and TGZ/TAR.GZ. Use `--type archive` to
force archive preview, or `--type binary` to inspect the raw bytes instead.

Binary files use the `binary` previewer and show offsets, color-coded bytes,
and an ASCII gutter. Add `--bits` to show each byte as eight bits instead of
hex digits, `--search-bytes` to color raw byte sequences white, and
`--search-text` to color UTF-8 text sequences white. Pass each byte pattern as
one hex string, and pass each text pattern as a normal UTF-8 string. Repeat
either flag to highlight multiple sequences. When an unknown file looks
binary, `peek` falls back to that view instead of trying to treat the input
as plain text.

## Documentation

The full manual lives in [peek-doc/peek.scrbl](peek-doc/peek.scrbl).

## Repository Layout

- `peek/` - launcher metadata for the `peek` command
- `peek-lib/` - the implementation library
- `peek-doc/` - the Scribble manual
- `test/` - regression and corpus tests

## License

The project is distributed under the MIT License. See [LICENSE](LICENSE).
