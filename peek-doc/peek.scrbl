#lang scribble/manual

@(require scribble-tools
          racket/file
          racket/runtime-path
          (for-label lexers/css
                     lexers/c
                     lexers/cpp
                     lexers/objc
                     lexers/csv
                     lexers/html
                     lexers/go
                     lexers/haskell
                     lexers/java
                     lexers/javascript
                     lexers/json
                     lexers/makefile
                     lexers/markdown
                     lexers/pascal
                     lexers/plist
                     lexers/tex
                     lexers/latex
                     lexers/python
                     lexers/racket
                     lexers/rhombus
                     lexers/rust
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

@(define-runtime-path css-preview-shot  "screenshots/example-css.png")
@(define-runtime-path html-preview-shot "screenshots/example-html.png")
@(define-runtime-path js-preview-shot   "screenshots/example-js.png")
@(define-runtime-path snippet-css       "snippets/css/example.css")
@(define-runtime-path snippet-html      "snippets/html/example.html")
@(define-runtime-path snippet-c         "snippets/c/example.c")
@(define-runtime-path snippet-cpp       "snippets/cpp/example.cpp")
@(define-runtime-path snippet-objc      "snippets/objc/example.m")
@(define-runtime-path snippet-go        "snippets/go/example.go")
@(define-runtime-path snippet-haskell   "snippets/haskell/example.hs")
@(define-runtime-path snippet-java      "snippets/java/example.java")
@(define-runtime-path snippet-pascal    "snippets/pascal/example.pas")
@(define-runtime-path snippet-python    "snippets/python/example.py")
@(define-runtime-path snippet-racket    "snippets/racket/example.rkt")
@(define-runtime-path snippet-rhombus   "snippets/rhombus/example.rhm")
@(define-runtime-path snippet-rust      "snippets/rust/example.rs")
@(define-runtime-path snippet-swift     "snippets/swift/example.swift")
@(define-runtime-path snippet-markdown  "snippets/markdown/example.md")
@(define-runtime-path snippet-scribble  "snippets/scribble/example.scrbl")
@(define-runtime-path snippet-tex       "snippets/tex/example.tex")
@(define-runtime-path snippet-latex     "snippets/latex/example.cls")
@(define-runtime-path snippet-makefile  "snippets/makefile/Makefile")
@(define-runtime-path snippet-shell     "snippets/shell/example.sh")
@(define-runtime-path snippet-binary    "snippets/binary/example.sh")
@(define-runtime-path snippet-csv       "snippets/csv/example.csv")
@(define-runtime-path snippet-json      "snippets/json/example.json")
@(define-runtime-path snippet-plist     "snippets/plist/example.plist")
@(define-runtime-path snippet-tsv       "snippets/tsv/example.tsv")
@(define-runtime-path snippet-wat       "snippets/wat/example.wat")
@(define-runtime-path snippet-yaml      "snippets/yaml/example.yaml")
@(define-runtime-path snippet-jsx       "snippets/javascript/example.jsx")
@(define-runtime-path snippet-css-shot       "screenshots/snippet-css.png")
@(define-runtime-path snippet-html-shot      "screenshots/snippet-html.png")
@(define-runtime-path snippet-jsx-shot       "screenshots/snippet-jsx.png")
@(define-runtime-path snippet-c-shot         "screenshots/snippet-c.png")
@(define-runtime-path snippet-cpp-shot       "screenshots/snippet-cpp.png")
@(define-runtime-path snippet-objc-shot      "screenshots/snippet-objc.png")
@(define-runtime-path snippet-go-shot        "screenshots/snippet-go.png")
@(define-runtime-path snippet-haskell-shot   "screenshots/snippet-haskell.png")
@(define-runtime-path snippet-java-shot      "screenshots/snippet-java.png")
@(define-runtime-path snippet-pascal-shot    "screenshots/snippet-pascal.png")
@(define-runtime-path snippet-python-shot    "screenshots/snippet-python.png")
@(define-runtime-path snippet-racket-shot    "screenshots/snippet-racket.png")
@(define-runtime-path snippet-rhombus-shot   "screenshots/snippet-rhombus.png")
@(define-runtime-path snippet-rust-shot      "screenshots/snippet-rust.png")
@(define-runtime-path snippet-swift-shot     "screenshots/snippet-swift.png")
@(define-runtime-path snippet-markdown-shot  "screenshots/snippet-markdown.png")
@(define-runtime-path snippet-scribble-shot  "screenshots/snippet-scribble.png")
@(define-runtime-path snippet-tex-shot       "screenshots/snippet-tex.png")
@(define-runtime-path snippet-latex-shot     "screenshots/snippet-latex.png")
@(define-runtime-path snippet-makefile-shot  "screenshots/snippet-makefile.png")
@(define-runtime-path snippet-shell-shot     "screenshots/snippet-shell.png")
@(define-runtime-path snippet-binary-shot    "screenshots/snippet-binary.png")
@(define-runtime-path snippet-csv-shot       "screenshots/snippet-csv.png")
@(define-runtime-path snippet-json-shot      "screenshots/snippet-json.png")
@(define-runtime-path snippet-plist-shot     "screenshots/snippet-plist.png")
@(define-runtime-path snippet-tsv-shot       "screenshots/snippet-tsv.png")
@(define-runtime-path snippet-wat-shot       "screenshots/snippet-wat.png")
@(define-runtime-path snippet-yaml-shot      "screenshots/snippet-yaml.png")
@(define (snippet-text path)
   (file->string path))
@(define (snippet-block path [indent 2])
   (verbatim #:indent indent (snippet-text path)))
@(define (preview-shot path)
   (image #:scale 0.3 path))

@section{Guide}

The tool @exec{peek} is a terminal utility for previewing files in the terminal.

This package is not intended for use by other Racket programs.
Installing the package will give you a command line tool @exec{peek} you
can use instead of @exec{less} in the terminal. The command @exec{peek}
appears in the same folder, the other Racket launchers do. 


There is file-type-aware rendering for the supported file types.

The supported file types are:

Binary, CSS, Bash, C, Objective-C, C++, CSV, HTML, Java, JavaScript, JSON,
LaTeX, Makefile, Go, Haskell, Markdown, Pascal, Plist, PowerShell, Python,
Rhombus, Racket, Rust, Scribble, Swift, TeX, TSV, WAT, YAML, and Zsh.


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

The Makefile previewer uses @tt{lexers/makefile} and supports ordinary
@tt{Makefile}, @tt{GNUmakefile}, and @tt{.mk} inputs as @tt{makefile}
preview targets. Recipe bodies now preserve Makefile-specific expansions such
as @tt{$(CC)} while using shell-aware roles for the command text itself.

The binary previewer shows raw bytes as a hex view with offsets, color-coded
bytes, and an ASCII gutter. It can be selected explicitly with
@tt{binary}, and unknown inputs that look binary fall back to that view
instead of trying to behave like plain text.

The CSV previewer uses @tt{lexers/csv} and supports @tt{.csv} files as
@tt{csv} preview targets.

The HTML previewer uses @tt{lexers/html} and reuses the CSS and JavaScript
color model for embedded @tt{<style>} and @tt{<script>} content.

The Go previewer uses @tt{lexers/go} and supports @tt{.go} files, plus Go
module files such as @tt{go.mod} and @tt{go.work}, as @tt{go} preview
targets.

The Haskell previewer uses @tt{lexers/haskell} and supports @tt{.hs},
@tt{.lhs}, @tt{.hs-boot}, and @tt{.lhs-boot} files as @tt{haskell} preview
targets.

The Java previewer uses @tt{lexers/java} and supports @tt{.java} source
files, including common package and module info files such as
@tt{package-info.java} and @tt{module-info.java}, as @tt{java} preview
targets.

The JavaScript previewer uses @tt{lexers/javascript}, and enables JSX-aware
classification for @tt{.jsx} files.

The JSON previewer uses @tt{lexers/json} and supports @tt{.json} and
@tt{.webmanifest} files as @tt{json} preview targets.

The Plist previewer uses @tt{lexers/plist} and supports XML property-list
files such as @tt{.plist} inputs as @tt{plist} preview targets.

The Python previewer uses @tt{lexers/python} and supports @tt{.py},
@tt{.pyi}, and @tt{.pyw} files as @tt{python} preview targets.

The Swift previewer uses @tt{lexers/swift} and supports @tt{.swift} files as
@tt{swift} preview targets.

The Rust previewer uses @tt{lexers/rust} and supports @tt{.rs} files as
@tt{rust} preview targets.

The Pascal previewer uses @tt{lexers/pascal} and supports common Pascal source
files such as @tt{.pas}, @tt{.pp}, @tt{.dpr}, @tt{.lpr}, and @tt{.inc} files
as @tt{pascal} preview targets.

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
for @tt{.rkt}, @tt{.ss}, @tt{.scm}, and @tt{.rktd} files. A bundled
standard-vocabulary map helps exact forms and builtins stand out from local
identifiers, and a small heuristic keeps form-like and binding-form-like
names readable.

The Scribble previewer uses @tt{lexers/scribble} and colors Scribble
command syntax plus embedded Racket escapes in @tt{.scrbl} files.

The WAT previewer uses @tt{lexers/wat} and provides first-pass syntax coloring for
WebAssembly text-format files in @tt{.wat}. 


@section{Command Line}

After installing the @exec{peek} package, the launcher is available as
@exec{peek}.

@shellblock[#:shell 'bash]{
peek path/to/file.css
peek path/to/file.bin
peek path/to/file.c
peek path/to/file.cpp
peek path/to/file.m
peek Makefile
peek GNUmakefile
peek path/to/file.mk
peek path/to/file.csv
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
}

When reading from standard input, use @DFlag{--type} to select the file type:

@shellblock[#:shell 'bash]{
cat path/to/file.css | peek --type css
cat path/to/file.bin | peek --type binary
cat path/to/file.c | peek --type c
cat path/to/file.cpp | peek --type cpp
cat path/to/file.m | peek --type objc
cat path/to/file.mk | peek --type makefile
cat path/to/file.csv | peek --type csv
cat path/to/file.html | peek --type html
cat path/to/file.go | peek --type go
cat path/to/file.java | peek --type java
cat path/to/file.hs | peek --type haskell
cat path/to/file.md | peek --type md
cat path/to/file.json | peek --type json
cat path/to/file.tex | peek --type tex
cat path/to/file.cls | peek --type latex
cat path/to/file.sty | peek --type latex
cat path/to/file.plist | peek --type plist
cat path/to/file.yaml | peek --type yaml
cat path/to/file.py | peek --type python
cat path/to/file.pas | peek --type pascal
cat path/to/file.rs | peek --type rust
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

HTML, JavaScript, JSON, LaTeX, Pascal, Plist, Python, JSX, Markdown, Rhombus,
Racket, Rust, Scribble, TeX, TSV, YAML, and WAT examples:

@shellblock[#:shell 'bash]{
peek path/to/file.html
peek path/to/file.c
peek path/to/file.csv
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
       @tt{html}, @tt{js}, @tt{json}, @tt{jsx}, @tt{latex}, @tt{md},
       @tt{pascal}, @tt{plist}, @tt{powershell}, @tt{python}, @tt{rhombus},
       @tt{rkt}, @tt{rust}, @tt{scrbl}, @tt{swift}, @tt{tex}, @tt{wat},
       @tt{yaml}, and @tt{zsh}.}
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

@section{Reference}

The current explicit file type names are:

@tt{binary}, @tt{bash}, @tt{c}, @tt{cpp}, @tt{css}, @tt{html}, @tt{js},
@tt{json}, @tt{jsx}, @tt{latex}, @tt{md}, @tt{plist}, @tt{powershell},
@tt{python}, @tt{rhombus}, @tt{rkt}, @tt{scrbl}, @tt{swift}, @tt{tex},
@tt{wat}, and @tt{zsh}.

@subsection{Web Languages}

@subsubsection{CSS}

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

@(snippet-block snippet-css)

Rendered CSS preview:

@(preview-shot snippet-css-shot)

@subsubsection{HTML}

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

@(verbatim (snippet-text snippet-html))

Rendered HTML preview:

@(preview-shot snippet-html-shot)

@subsubsection{JavaScript And JSX}

For JavaScript, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for JavaScript files such as @tt{.js}, @tt{.mjs}, and
       @tt{.cjs}}
 @item{syntax coloring for JSX in @tt{.jsx} files}
 @item{derived-tag-driven rendering built on @tt{lexers/javascript}}
]

The first JavaScript pass focuses on syntax coloring only. It does not yet add
preview widgets or framework-specific heuristics.

Example JavaScript preview input:

@(verbatim (snippet-text snippet-jsx))

Rendered JavaScript / JSX preview:

@(preview-shot snippet-jsx-shot)

@subsection{Programming Languages}

@subsubsection{C}

For C, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.c} and @tt{.h} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The C previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example C preview input:

@(snippet-block snippet-c)

Rendered C preview:

@(preview-shot snippet-c-shot)

@subsubsection{C++}

For C++, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for common C++ source and header extensions such as
       @tt{.cpp}, @tt{.cc}, @tt{.cxx}, @tt{.cp}, @tt{.c++}, @tt{.cppm},
       @tt{.ixx}, @tt{.hpp}, @tt{.hh}, @tt{.hxx}, @tt{.h++}, @tt{.ipp}, and
       @tt{.tpp}}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The C++ previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example C++ preview input:

@(snippet-block snippet-cpp)

Rendered C++ preview:

@(preview-shot snippet-cpp-shot)

@subsubsection{Objective-C}

For Objective-C, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.m} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Objective-C previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Objective-C preview input:

@(verbatim (snippet-text snippet-objc))

Rendered Objective-C preview:

@(preview-shot snippet-objc-shot)

@subsubsection{Go}

For Go, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.go} files and module files such as
       @tt{go.mod} and @tt{go.work}}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Go previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Go preview input:

@(snippet-block snippet-go)

Rendered Go preview:

@(preview-shot snippet-go-shot)

@subsubsection{Haskell}

For Haskell, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.hs}, @tt{.lhs}, @tt{.hs-boot}, and
       @tt{.lhs-boot} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Haskell previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Haskell preview input:

@(snippet-block snippet-haskell)

Rendered Haskell preview:

@(preview-shot snippet-haskell-shot)

@subsubsection{Java}

For Java, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.java} source files, including
       @tt{package-info.java} and @tt{module-info.java}}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Java previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Java preview input:

@(verbatim (snippet-text snippet-java))

Rendered Java preview:

@(preview-shot snippet-java-shot)

@subsubsection{Pascal}

For Pascal, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for common Pascal source files such as @tt{.pas},
       @tt{.pp}, @tt{.dpr}, @tt{.lpr}, and @tt{.inc}}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Pascal previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Pascal preview input:

@(snippet-block snippet-pascal)

Rendered Pascal preview:

@(preview-shot snippet-pascal-shot)

@subsubsection{Python}

For Python, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.py}, @tt{.pyi}, and @tt{.pyw} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Python previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Python preview input:

@(snippet-block snippet-python)

Rendered Python preview:

@(preview-shot snippet-python-shot)

@subsubsection{Racket}

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

@(snippet-block snippet-racket)

Rendered Racket preview:

@(preview-shot snippet-racket-shot)

@subsubsection{Rhombus}

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

@(snippet-block snippet-rhombus)

Rendered Rhombus preview:

@(preview-shot snippet-rhombus-shot)

@subsubsection{Rust}

For Rust, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for Rust source in @tt{.rs} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Rust previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Rust preview input:

@(snippet-block snippet-rust)

Rendered Rust preview:

@(preview-shot snippet-rust-shot)

@subsubsection{Swift}

For Swift, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.swift} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Swift previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Swift preview input:

@(snippet-block snippet-swift)

Rendered Swift preview:

@(preview-shot snippet-swift-shot)

@subsection{Document Languages}

@subsubsection{Markdown}

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

Markdown code fences can now delegate to more embedded file types, including
C, JSON, Pascal, Python, Rust, shell, YAML, and CSV/TSV, when `lexers`
exposes the corresponding embedded tags.

Example Markdown preview input:

@(snippet-block snippet-markdown)

Rendered Markdown preview:

@(preview-shot snippet-markdown-shot)

@subsubsection{Scribble}

For Scribble, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.scrbl} files}
 @item{derived-tag-driven rendering built on @tt{lexers/scribble}}
 @item{plain text left unstyled while command syntax is colored}
 @item{Racket-like coloring for tokens inside Scribble Racket escapes}
]

The first Scribble pass is intentionally color-only. It does not try to render
Scribble as a document view; it stays a syntax-oriented terminal preview.

When you need a literal at-sign in Scribble prose, write @"@".

Example Scribble preview input:

@(verbatim (snippet-text snippet-scribble))

Rendered Scribble preview:

@(preview-shot snippet-scribble-shot)

@subsubsection{TeX}

For TeX, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.tex} source}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The TeX previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping. Its coloring now pays attention to math shifts, accent and
spacing commands, parameters, and delimiters instead of flattening them all
into one generic command class.

Example TeX preview input:

@(snippet-block snippet-tex)

Rendered TeX preview:

@(preview-shot snippet-tex-shot)

@subsubsection{LaTeX}

For LaTeX, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for common LaTeX source files such as @tt{.cls},
       @tt{.sty}, @tt{.latex}, and @tt{.ltx}}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The LaTeX previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping. Its coloring keeps environment names, `@tt{\verb}` spans,
and line-break commands visible as distinct structure.

Example LaTeX preview input:

@(snippet-block snippet-latex)

Rendered LaTeX preview:

@(preview-shot snippet-latex-shot)

@subsection{Tooling and Config}

@subsubsection{Makefile}

For Makefiles, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for ordinary @tt{Makefile}, @tt{GNUmakefile}, and
       @tt{.mk} inputs}
 @item{shell-aware recipe bodies with Makefile-specific variable references
       preserved}
 @item{best-effort previewing on malformed input}
]

The Makefile previewer is intentionally color-only except for its shell-aware
recipe handling. It preserves Makefile variable references and line breaks
without layout rewriting.

Example Makefile preview input:

@(snippet-block snippet-makefile)

Rendered Makefile preview:

@(preview-shot snippet-makefile-shot)

@subsubsection{Shell}

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

@(verbatim (snippet-text snippet-shell))

Rendered shell preview:

@(preview-shot snippet-shell-shot)

@subsection{Binary Files}

For Binary, @exec{peek} currently supports:

@itemlist[
 @item{hex-style previewing for arbitrary binary data}
 @item{explicit @tt{binary} mode for stdin and files}
 @item{@tt{--bits} to show each byte as bits instead of hex digits}
 @item{@tt{--search-bytes} to highlight raw byte sequences in white}
 @item{@tt{--search-text} to highlight UTF-8 text sequences in white}
 @item{automatic fallback to binary when unknown input looks non-textual}
]

The binary previewer is intentionally hex-oriented by default. It shows
offsets, color groups for bytes, and an ASCII gutter, and @tt{--bits} swaps
the byte cells to 8-bit binary strings. @tt{--search-bytes} highlights the
matched bytes in white, and each pattern can be expressed as one hex string
such as @tt{4243}; repeat the flag to add more patterns. @tt{--search-text}
highlights UTF-8 text sequences in white, and each pattern is a normal text
string; repeat the flag to add more patterns. The previewer does not try to
interpret the bytes as structured text.

Example binary preview input:

@(snippet-block snippet-binary)

Rendered binary preview:

@(preview-shot snippet-binary-shot)

@subsection{Data Formats}

@subsubsection{CSV}

For CSV, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.csv} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The CSV previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example CSV preview input:

@(snippet-block snippet-csv)

Rendered CSV preview:

@(preview-shot snippet-csv-shot)

@subsubsection{JSON}

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

@(snippet-block snippet-json)

Rendered JSON preview:

@(preview-shot snippet-json-shot)

@subsubsection{Plist}

For Plist, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for XML property-list files in @tt{.plist} inputs}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The Plist previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example Plist preview input:

@(snippet-block snippet-plist)

Rendered Plist preview:

@(preview-shot snippet-plist-shot)

@subsubsection{TSV}

For TSV, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.tsv} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The TSV previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example TSV preview input:

@(snippet-block snippet-tsv)

Rendered TSV preview:

@(preview-shot snippet-tsv-shot)

@subsubsection{WAT}

For WAT, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for WebAssembly text-format files in @tt{.wat}}
 @item{best-effort previewing on malformed input}
 @item{delegated WAT coloring in fenced Markdown code blocks when
       @tt{lexers/markdown} exposes @tt{embedded-wat}}
]

The first WAT pass is intentionally color-only. It does not add
indentation normalization, formatting, or spec-link behavior. Standalone WAT
preview is one of the streaming render paths in @exec{peek}; all current file
types now use the port-oriented streaming path.

Example WAT preview input:

@(snippet-block snippet-wat)

Rendered WAT preview:

@(preview-shot snippet-wat-shot)

@subsubsection{YAML}

For YAML, @exec{peek} currently supports:

@itemlist[
 @item{syntax coloring for @tt{.yaml} and @tt{.yml} files}
 @item{best-effort previewing on malformed input}
 @item{source-preserving, color-only terminal output}
]

The YAML previewer is intentionally color-only. It does not add layout
rewriting or alignment, and it preserves source text and line breaks after
ANSI stripping.

Example YAML preview input:

@(snippet-block snippet-yaml)

Rendered YAML preview:

@(preview-shot snippet-yaml-shot)

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

The current implementation focuses on CSS, HTML, Java, JavaScript, Markdown,
Racket, Scribble, TeX, LaTeX, WAT, Shell, Makefile, and the data-format
previewers. Most supported lexers use the port-oriented streaming path.
CSS remains the special buffered renderer because it can add swatches and
alignment. Future file types may add their own previewers without forcing all
file types into the same rendering model.

@section{Screenshots}

@subsection{Gallery}

Representative previews, rendered by @exec{peek}:

@(define-runtime-path img-bash      "screenshots/example-bash.png")
@(define-runtime-path img-c         "screenshots/example-c.png")
@(define-runtime-path img-cpp       "screenshots/example-cpp.png")
@(define-runtime-path img-css       "screenshots/example-css.png")
@(define-runtime-path img-csv       "screenshots/example-csv.png")
@(define-runtime-path img-go        "screenshots/example-go.png")
@(define-runtime-path img-haskell   "screenshots/example-hs.png")
@(define-runtime-path img-html      "screenshots/example-html.png")
@(define-runtime-path img-java      "screenshots/example-java.png")
@(define-runtime-path img-js        "screenshots/example-js.png")
@(define-runtime-path img-jsx       "screenshots/example-jsx.png")
@(define-runtime-path img-json      "screenshots/example-json.png")
@(define-runtime-path img-latex     "screenshots/example-cls.png")
@(define-runtime-path img-markdown  "screenshots/example-md.png")
@(define-runtime-path img-makefile  "screenshots/Makefile.png")
@(define-runtime-path img-objc      "screenshots/example-m.png")
@(define-runtime-path img-pascal    "screenshots/example-pas.png")
@(define-runtime-path img-plist     "screenshots/example-plist.png")
@(define-runtime-path img-powershell "screenshots/example-ps1.png")
@(define-runtime-path img-python    "screenshots/example-py.png")
@(define-runtime-path img-racket    "screenshots/example-racket.png")
@(define-runtime-path img-rhombus   "screenshots/example-rhm.png")
@(define-runtime-path img-rust      "screenshots/example-rs.png")
@(define-runtime-path img-scribble  "screenshots/example-scrbl.png")
@(define-runtime-path img-shell     "screenshots/example-sh.png")
@(define-runtime-path img-swift     "screenshots/example-swift.png")
@(define-runtime-path img-tex       "screenshots/example-tex.png")
@(define-runtime-path img-tsv       "screenshots/example-tsv.png")
@(define-runtime-path img-wat       "screenshots/example-wat.png")
@(define-runtime-path img-yaml      "screenshots/example-yaml.png")
@(define-runtime-path img-zsh       "screenshots/example-zsh.png")

@tabular[
 #:sep @hspace[2]
 (list
  (list @bold{Bash}        @(image #:scale 0.3 img-bash))
  (list @bold{C}           @(image #:scale 0.3 img-c))
  (list @bold{C++}         @(image #:scale 0.3 img-cpp))
  (list @bold{CSS}         @(image #:scale 0.3 img-css))
  (list @bold{CSV}         @(image #:scale 0.3 img-csv))
  (list @bold{Go}          @(image #:scale 0.3 img-go))
  (list @bold{Haskell}     @(image #:scale 0.3 img-haskell))
  (list @bold{HTML}        @(image #:scale 0.3 img-html))
  (list @bold{Java}        @(image #:scale 0.3 img-java))
  (list @bold{JavaScript}  @(image #:scale 0.3 img-js))
  (list @bold{JSX}         @(image #:scale 0.3 img-jsx))
  (list @bold{JSON}        @(image #:scale 0.3 img-json))
  (list @bold{LaTeX}       @(image #:scale 0.3 img-latex))
  (list @bold{Markdown}    @(image #:scale 0.3 img-markdown))
  (list @bold{Makefile}    @(image #:scale 0.3 img-makefile))
  (list @bold{Objective-C} @(image #:scale 0.3 img-objc))
  (list @bold{Pascal}      @(image #:scale 0.3 img-pascal))
  (list @bold{Plist}       @(image #:scale 0.3 img-plist))
  (list @bold{PowerShell}  @(image #:scale 0.3 img-powershell))
  (list @bold{Python}      @(image #:scale 0.3 img-python))
  (list @bold{Racket}      @(image #:scale 0.3 img-racket))
  (list @bold{Rhombus}     @(image #:scale 0.3 img-rhombus))
  (list @bold{Rust}        @(image #:scale 0.3 img-rust))
  (list @bold{Scribble}    @(image #:scale 0.3 img-scribble))
  (list @bold{Shell}       @(image #:scale 0.3 img-shell))
  (list @bold{Swift}       @(image #:scale 0.3 img-swift))
  (list @bold{TeX}         @(image #:scale 0.3 img-tex))
  (list @bold{TSV}         @(image #:scale 0.3 img-tsv))
  (list @bold{WAT}         @(image #:scale 0.3 img-wat))
  (list @bold{YAML}        @(image #:scale 0.3 img-yaml))
  (list @bold{Zsh}         @(image #:scale 0.3 img-zsh)))]
