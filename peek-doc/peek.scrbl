#lang scribble/manual

@(require scribble-tools
          racket/runtime-path
          (for-label lexers/css
                     lexers/c
                     lexers/cpp
                     lexers/objc
                     lexers/csv
                     lexers/html
                     lexers/javascript
                     lexers/json
                     lexers/markdown
                     lexers/python
                     lexers/racket
                     lexers/rhombus
                     lexers/shell
                     lexers/swift
                     lexers/yaml
                     lexers/tsv
                     lexers/scribble
                     lexers/wat
                     racket/base
                     (lib "peek/main.rkt")
                     (lib "peek/preview.rkt")))

@title{peek}
@author[@author+email["Jens Axel Søgaard" "jensaxel@soegaard.net"]]
@defmodule[(lib "peek/main.rkt")]

The tool @exec{peek} is a terminal utility for previewing files in the terminal.

This package is not intended for use by other Racket programs.
Installing the package will give you a command line tool @exec{peek} you
can use instead of @exec{less} in the terminal. The command @exec{peek}
appears in the same folder, the other Racket launchers do. 


There is file-type-aware rendering for the supported file types.

The supported file types are:

CSS, Bash, C, Objective-C, C++, CSV, HTML, JavaScript, JSON, Markdown,
PowerShell, Python, Rhombus, Racket, Scribble, Swift, TSV, WAT, YAML,
and Zsh.


The CSS previewer uses @tt{lexers/css} for lexing and adds terminal-oriented rendering
features such as syntax coloring, color swatches, and optional alignment.

The C previewer uses @tt{lexers/c} and supports @tt{.c} and @tt{.h} files as
@tt{c} preview targets.

The Objective-C previewer uses @tt{lexers/objc} and supports @tt{.m} files as
@tt{objc} preview targets.

The C++ previewer uses @tt{lexers/cpp} and supports common C++ source and
header extensions such as @tt{.cpp}, @tt{.cc}, @tt{.cxx}, @tt{.cp},
@tt{.c++}, @tt{.cppm}, @tt{.ixx}, @tt{.hpp}, @tt{.hh}, @tt{.hxx},
@tt{.h++}, @tt{.ipp}, and @tt{.tpp} files as @tt{cpp} preview targets.

The CSV previewer uses @tt{lexers/csv} and supports @tt{.csv} files as
@tt{csv} preview targets.

The HTML previewer uses @tt{lexers/html} and reuses the CSS and JavaScript
color model for embedded @tt{<style>} and @tt{<script>} content.

The JavaScript previewer uses @tt{lexers/javascript}, and enables JSX-aware
classification for @tt{.jsx} files.

The JSON previewer uses @tt{lexers/json} and supports @tt{.json} and
@tt{.webmanifest} files as @tt{json} preview targets.

The Python previewer uses @tt{lexers/python} and supports @tt{.py},
@tt{.pyi}, and @tt{.pyw} files as @tt{python} preview targets.

The Swift previewer uses @tt{lexers/swift} and supports @tt{.swift} files as
@tt{swift} preview targets.

The shell previewers use @tt{lexers/shell} and support @tt{.sh}, @tt{.bash},
@tt{.zsh}, and @tt{.ps1} files as @tt{bash}, @tt{zsh}, and @tt{powershell}
preview targets.

The Rhombus previewer uses @tt{lexers/rhombus} and supports @tt{.rhm} files
as @tt{rhombus} preview targets.

The YAML previewer uses @tt{lexers/yaml} and supports @tt{.yaml} and
@tt{.yml} files as @tt{yaml} preview targets.

The TSV previewer uses @tt{lexers/tsv} and supports @tt{.tsv} files as
@tt{tsv} preview targets.

The Markdown previewer uses @tt{lexers/markdown} and colors Markdown structure
plus delegated embedded languages in @tt{.md} files.

The Racket previewer uses @tt{lexers/racket} and provides syntax coloring
for @tt{.rkt}, @tt{.ss}, @tt{.scm}, and @tt{.rktd} files.

The Scribble previewer uses @tt{lexers/scribble} and colors Scribble
command syntax plus embedded Racket escapes in @tt{.scrbl} files.

The WAT previewer uses @tt{lexers/wat} and provides first-pass syntax coloring for
WebAssembly text-format files in @tt{.wat}. 


@section{Screenshots}

A few small previews, rendered by @exec{peek}:

@(define-runtime-path img-css    "screenshots/example-css.png")
@(define-runtime-path img-html   "screenshots/example-html.png")
@(define-runtime-path img-racket "screenshots/example-racket.png")
@(define-runtime-path img-wat    "screenshots/example-wat.png")

@(image #:scale 0.5 img-css)

@(image #:scale 0.5 img-html)

@(image #:scale 0.5 img-racket)

@(image #:scale 0.5 img-wat)

@section{Command Line}

After installing the @exec{peek} package, the launcher is available as
@exec{peek}.

@shellblock[#:shell 'bash]{
peek path/to/file.css
peek path/to/file.c
peek path/to/file.cpp
peek path/to/file.m
peek path/to/file.csv
peek path/to/file.html
peek path/to/file.js
peek path/to/file.json
peek path/to/file.yaml
peek path/to/file.py
peek path/to/file.swift
peek path/to/file.md
peek path/to/file.rhm
peek path/to/file.rkt
peek path/to/file.ss
peek path/to/file.scrbl
peek path/to/file.wat
}

When reading from standard input, use @DFlag{--type} to select the file type:

@shellblock[#:shell 'bash]{
cat path/to/file.css | peek --type css
cat path/to/file.c | peek --type c
cat path/to/file.cpp | peek --type cpp
cat path/to/file.m | peek --type objc
cat path/to/file.csv | peek --type csv
cat path/to/file.html | peek --type html
cat path/to/file.md | peek --type md
cat path/to/file.json | peek --type json
cat path/to/file.yaml | peek --type yaml
cat path/to/file.py | peek --type python
cat path/to/file.swift | peek --type swift
cat path/to/file.rhm | peek --type rhombus
cat path/to/file.rkt | peek --type rkt
cat path/to/file.ss | peek --type rkt
cat path/to/file.scrbl | peek --type scrbl
cat path/to/file.wat | peek --type wat
}

To list the currently supported explicit file type names:

@shellblock[#:shell 'bash]{
peek --list-file-types
}

Useful CSS examples:

@shellblock[#:shell 'bash]{
peek -a path/to/file.css
peek --no-swatches path/to/file.css
peek --color never path/to/file.css
peek --color auto path/to/file.css | less -R
peek -p path/to/file.css
}

HTML, JavaScript, JSON, Python, JSX, Markdown, Rhombus, Racket, Scribble,
TSV, YAML, and WAT examples:

@shellblock[#:shell 'bash]{
peek path/to/file.html
peek path/to/file.c
peek path/to/file.csv
peek path/to/file.js
peek path/to/file.json
peek path/to/file.yaml
peek path/to/file.py
peek path/to/component.jsx
peek path/to/file.md
peek path/to/file.rhm
peek path/to/file.rkt
peek path/to/file.ss
peek path/to/file.scrbl
peek path/to/file.wat
}

Rhombus examples:

@shellblock[#:shell 'bash]{
peek path/to/file.rhm
}

Shell examples:

@shellblock[#:shell 'bash]{
peek path/to/script.sh
peek path/to/script.bash
peek path/to/script.zsh
peek path/to/script.ps1
}

@subsection{Options}

@itemlist[
 @item{@DFlag{--type} @italic{type}
    selects the input type explicitly. This is mainly useful for standard
       input. Supported values are @tt{bash}, @tt{c}, @tt{cpp}, @tt{css},
       @tt{html}, @tt{js}, @tt{json}, @tt{jsx}, @tt{md}, @tt{powershell},
       @tt{python}, @tt{rhombus}, @tt{rkt}, @tt{scrbl}, @tt{swift},
       @tt{wat}, @tt{yaml}, and @tt{zsh}.}
 @item{@DFlag{--list-file-types}
       prints the currently supported explicit file type names, one per line,
       and exits.}
 @item{@Flag{-a}, @DFlag{--align}
       enables CSS-specific alignment. This may rewrite spacing to improve the
       readability of declarations and aligned rule groups.}
 @item{@DFlag{--no-swatches}
       disables CSS color swatches while keeping syntax coloring enabled.}
 @item{@Flag{-p}, @DFlag{--pager}
       sends preview output through the configured pager. @exec{peek} uses the
       @envvar{PAGER} environment variable when it is set, and otherwise falls
       back to @tt{less -R}.}
 @item{@DFlag{--color} @litchar{always}@litchar{|}@litchar{auto}@litchar{|}@litchar{never}
       controls ANSI color output. The default is @litchar{always}.}
]

@subsection{Color Modes}

@itemlist[
 @item{@litchar{always} always emits ANSI color and other terminal styling.}
 @item{@litchar{auto} emits color only when the output port is a terminal.}
 @item{@litchar{never} disables color and prints plain text.}
]

@subsection{Pagers}

Use @Flag{-p} or @DFlag{--pager} when you want @exec{peek} to open its output
in a pager instead of writing directly to the terminal.

By default, @exec{peek} uses:

@itemlist[
 @item{the command named by @envvar{PAGER}, if that environment variable is set}
 @item{@tt{less -R}, otherwise}
]

On Unix-like systems, a common usage is:

@shellblock[#:shell 'bash]{
peek -p path/to/file.css
}

or, with an explicit pager selection:

@shellblock[#:shell 'bash]{
PAGER="less -R" peek -p path/to/file.css
}

On Windows, pager availability depends on what is installed. One practical
approach is to point @envvar{PAGER} at an installed pager explicitly. For
example, if @tt{less.exe} is available from Git for Windows:

@shellblock[#:shell 'powershell]{
$env:PAGER = "C:\Program Files\Git\usr\bin\less.exe -R"
peek -p path\to\file.css
}

If @envvar{PAGER} is not set and @tt{less} is not installed, pager mode will
fail with an error instead of silently falling back to plain output.

@section{Supported File Types}

The current explicit file type names are:

@itemlist[
 @item{@tt{bash}}
 @item{@tt{c}}
 @item{@tt{cpp}}
 @item{@tt{css}}
 @item{@tt{html}}
 @item{@tt{js}}
 @item{@tt{json}}
 @item{@tt{jsx}}
 @item{@tt{md}}
 @item{@tt{powershell}}
 @item{@tt{python}}
 @item{@tt{rhombus}}
 @item{@tt{rkt}}
 @item{@tt{scrbl}}
 @item{@tt{swift}}
 @item{@tt{wat}}
 @item{@tt{zsh}}
]

@subsection{CSS}

For CSS, @exec{peek} supports:

@itemlist[
 @item{syntax coloring}
 @item{color swatches for practical color literals and supported color
       functions}
 @item{best-effort previewing on malformed input}
 @item{optional alignment for declarations and simple repeated rule shapes}
]

The CSS aligner is intentionally opinionated and terminal-focused. It may:

@itemlist[
 @item{align property columns inside a block}
 @item{align numeric values, including decimal/unit alignment}
 @item{align repeated simple rule groups across sibling rules}
 @item{align repeated function-call argument shapes, such as repeated
       @litchar{rgba(...)} calls, when that improves scanability}
]

Swatches are part of the rendered output. Alignment is therefore computed from
rendered width, not only from source-text width.

Example CSS preview input:

@cssblock[#:color-swatch? #t]{
.card {
  color: #2f7ea0;
  box-shadow: 0 4px 10px rgba(0, 0, 0, 0.20);
}
}

@subsection{HTML}

For HTML, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for HTML structure such as tag names, attribute names,
       attribute values, comments, entities, and doctypes}
 @item{best-effort previewing on malformed input}
 @item{embedded CSS coloring inside @tt{<style>} elements}
 @item{embedded JavaScript coloring inside @tt{<script>} elements}
]

The first HTML pass is intentionally color-only. It does not yet add
HTML-specific layout transforms, and it does not enable CSS swatches or
alignment inside embedded @tt{<style>} regions.

Example HTML preview input:

@htmlblock{
<!doctype html>
<main id="app">
  <style>.hero { color: #2f7ea0; }</style>
  <script>const root = document.querySelector("#app");</script>
  <p>Hello &amp; goodbye.</p>
</main>
}

@subsection{Shell}

For Shell, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for Bash, Zsh, and PowerShell source}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The shell previewers are intentionally color-only. They do not add layout
rewriting or alignment, and they preserve source text and line breaks after
ANSI stripping.

Example shell preview input:

@shellblock[#:shell 'bash]{
#!/usr/bin/env bash
export PATH
echo "$PATH"
}

@subsection{Rhombus}

For Rhombus, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for Rhombus source in @tt{.rhm} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Rhombus previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Rhombus preview input:

@shellblock[#:shell 'bash]{
#lang rhombus
fun greet(name):
  println("hello, $(name)")
}

@subsection{Markdown}

For Markdown, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for GitHub-Flavored Markdown structure in @tt{.md}
       files}
 @item{plain rendering for ordinary prose}
 @item{embedded-language coloring for delegated raw HTML and recognized fenced
       code languages}
 @item{best-effort previewing on malformed input}
]

The first Markdown pass is intentionally color-only. It does not attempt to
render Markdown as formatted documentation, and it does not rewrite table or
list layout.

Example Markdown preview input:

@verbatim[#:indent 2]{
# Demo

Text with `code`, a [link](https://example.com), and:

```rkt
(define x 1)
```
}

@subsection{JavaScript And JSX}

For JavaScript, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for JavaScript files such as @tt{.js}, @tt{.mjs}, and
       @tt{.cjs}}
 @item{syntax coloring for JSX in @tt{.jsx} files}
 @item{derived-tag-driven rendering built on @tt{lexers/javascript}}
]

The first JavaScript pass focuses on syntax coloring only. It does not yet add
preview widgets or framework-specific heuristics.

Example JSX preview input:

@jsblock[#:jsx? #t]{
const view = <Button kind="primary">Hello {name}</Button>;
}

@subsection{JSON}

For JSON, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for ordinary JSON source in @tt{.json} and
       @tt{.webmanifest} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The JSON previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example JSON preview input:

@verbatim[#:indent 2]{
{
  "name": "peek",
  "ok": true,
  "count": 2
}
}

@subsection{WAT}

For WAT, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for WebAssembly text-format files in @tt{.wat}}
 @item{best-effort previewing on malformed input}
 @item{delegated WAT coloring in fenced Markdown code blocks when
       @tt{lexers/markdown} exposes @tt{embedded-wat}}
]

The first WAT pass is intentionally color-only. It does not add
indentation normalization, formatting, or spec-link behavior. Standalone WAT
preview is also the first file type to use the streaming render path in
@exec{peek}; other current file types still use the existing buffered preview
path.

Example WAT preview input:

@verbatim[#:indent 2]{
(module
  (func $answer (result i32)
    i32.const 42)
  (export "answer" (func $answer)))
}

@subsection{Racket}

For Racket, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.rkt} files}
 @item{derived-tag-driven rendering built on @tt{lexers/racket}}
 @item{best-effort previewing in coloring mode}
]

The first Racket pass is intentionally color-only. It does not yet add
structure-aware formatting or separate support for nearby file types such as
@tt{.rktl}.

Example Racket preview input:

@racketblock{
#lang racket/base

; Greeting helper.
#;(+ 1 2)
(define (greet #:name [name "you"])
  (string-append "hi " name))
}

@subsection{Scribble}

For Scribble, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.scrbl} files}
 @item{derived-tag-driven rendering built on @tt{lexers/scribble}}
 @item{plain text left unstyled while command syntax is colored}
 @item{Racket-like coloring for tokens inside Scribble Racket escapes}
]

The first Scribble pass is intentionally color-only. It does not try to render
Scribble as a document view; it stays a syntax-oriented terminal preview.

Example Scribble preview input:

@scribbleblock[
  "#lang scribble/manual\n"
  "\n"
  "@title{peek Scribble Demo}\n"
  "\n"
  "This is plain text.\n"
  "\n"
  "Inline Racket: @racket[(define x 1)]\n"]

@section{Library}

The command-line tool is backed by a small library in
@racketmodname[(lib "peek/preview.rkt")].

The initial library surface is intentionally small:

@itemlist[
 @item{@tt{make-preview-options} constructs a preview-options value with
       optional type, alignment, swatch, and color-mode settings.}
 @item{@tt{preview-string} previews a source string using the selected
       options.}
 @item{@tt{preview-port} previews from an input port to an output port. This
       is the lower-level entry point used by streaming previewers such as
       standalone WAT.}
 @item{@tt{preview-file} reads a file and previews it using the selected
       options.}
]

The command-line entry point lives in
@racketmodname[(lib "peek/main.rkt")] and is exported as @tt{main}.

@section{Notes}

Unsupported file types currently fall back to plain text.

The current implementation focuses on CSS, HTML, JavaScript, Markdown,
Racket, Scribble, WAT, and a small generic preview pipeline. All supported
lexers now use the port-oriented streaming path. Future file types may add
their own previewers without forcing all file types into the same rendering
model.
