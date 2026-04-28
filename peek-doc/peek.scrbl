#lang scribble/manual

@(require scribble-tools
          scribble/core
          racket/file
          racket/path
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

@italic{Note:} The @tt{peek} package and this documentation were written
with Codex.

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
@(define-runtime-path binary-all-bytes  "snippets/binary/all-bytes.bin")
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
@(define-runtime-path snippet-binary-shot-1  "screenshots/snippet-binary-auto.png")
@(define-runtime-path snippet-binary-shot-2  "screenshots/snippet-binary-search-42.png")
@(define-runtime-path snippet-binary-shot-3  "screenshots/snippet-binary-search-sequence.png")
@(define-runtime-path snippet-binary-shot-4  "screenshots/snippet-binary-search-text.png")
@(define-runtime-path snippet-csv-shot       "screenshots/snippet-csv.png")
@(define-runtime-path snippet-json-shot      "screenshots/snippet-json.png")
@(define-runtime-path snippet-plist-shot     "screenshots/snippet-plist.png")
@(define-runtime-path snippet-tsv-shot       "screenshots/snippet-tsv.png")
@(define-runtime-path snippet-wat-shot       "screenshots/snippet-wat.png")
@(define-runtime-path snippet-yaml-shot      "screenshots/snippet-yaml.png")
@(define (snippet-text path)
   (file->string path))
@(define (snippet-name path)
   (path->string (file-name-from-path path)))
@(define-syntax-rule (input-block block-form path)
   (block-form #:line-numbers 1
               #:file (snippet-name path)
               (snippet-text path)))
@(define-syntax-rule (input-shell path shell-kind)
   (shellblock #:shell shell-kind
               #:line-numbers 1
               #:file (snippet-name path)
               (snippet-text path)))
@(define-syntax-rule (input-scribble path)
   (scribbleblock #:context #'here
                  #:line-numbers 1
                  #:file (snippet-name path)
                  (snippet-text path)))
@(define (long-flag name)
   (make-element 'no-break
                 (list (tt "-")
                       (tt "-")
                       (make-element 'tt (list name)))))
@(define (preview-shot path)
   (image #:scale 0.3 path))

@section{Guide}

@exec{peek} previews files directly in the terminal, with syntax-aware
coloring for supported file types, tree previews for supported archives, and
a binary fallback for non-text data.

It is meant as a command-line viewing tool, not as a general-purpose library.
After installing the package, you get a @exec{peek} launcher alongside the
other Racket command-line tools.

@subsection{Quick Start}

The fastest way to get a feel for @exec{peek} is to run it on a file you
already have:

@shellblock[#:shell 'bash]{
peek path/to/file.css
peek -P path/to/file.css
cat path/to/file.json | peek --type json
}

By default, @exec{peek} opens rendered output in a pager. Use @Flag{-P} or
@(long-flag "no-pager") when you want direct terminal output instead, and use
@Flag{-p} or @(long-flag "pretty") when you want a supported previewer to use
its prettier terminal rendering, and use @(long-flag "type") when reading
from standard input or when you want to force a specific previewer such as
@tt{archive} or @tt{binary}.

@subsection{Supported Types}

Supported file types are grouped in the reference chapter, but the current
surface includes:

@itemlist[
 @item{@bold{Web languages:} @seclink["css"]{CSS}, @seclink["html"]{HTML},
       @seclink["javascript-jsx"]{JavaScript}, and
       @seclink["javascript-jsx"]{JSX}}
 @item{@bold{Programming languages:} @seclink["shell"]{Bash},
       @seclink["c"]{C}, @seclink["objective-c"]{Objective-C},
       @seclink["cpp"]{C++}, @seclink["go"]{Go},
       @seclink["haskell"]{Haskell}, @seclink["java"]{Java},
       @seclink["pascal"]{Pascal}, @seclink["shell"]{PowerShell},
       @seclink["python"]{Python}, @seclink["rhombus"]{Rhombus},
       @seclink["racket"]{Racket}, @seclink["rust"]{Rust},
       @seclink["swift"]{Swift}, and @seclink["shell"]{Zsh}}
 @item{@bold{Document languages:} @seclink["markdown"]{Markdown},
       @seclink["scribble"]{Scribble}, @seclink["tex"]{TeX}, and
       @seclink["latex"]{LaTeX}}
 @item{@bold{Data and tooling formats:} @seclink["csv"]{CSV},
       @seclink["json"]{JSON}, @seclink["makefile"]{Makefile},
       @seclink["plist"]{Plist}, @seclink["tsv"]{TSV}, @seclink["wat"]{WAT},
       and @seclink["yaml"]{YAML}}
 @item{@bold{Archive files:} @seclink["archive-files"]{Archive Files}}
 @item{@bold{Binary files:} automatic binary detection plus explicit
       @seclink["binary-files"]{@tt{binary}} mode}
]

See @secref{Reference} for the detailed behavior, examples, and screenshots
for each supported type.

@subsection{What Makes Peek Useful}

The previewers aim to stay terminal-first:

@itemlist[
 @item{show useful syntax structure without rewriting the source into a
       document view}
 @item{preserve source text and line breaks in the color-oriented previewers}
 @item{use file-type-aware lexers where available instead of one generic
       text highlighter}
 @item{show a directory tree for supported archives instead of raw bytes}
 @item{fall back to a readable binary view for non-text input}
]

Here is a representative CSS preview:

@(preview-shot css-preview-shot)


@subsection{Installation}

@itemlist[
 @item{Go to @hyperlink["https://download.racket-lang.org/"]{
       download.racket-lang.org} to download and install Racket.}
 @item{Use @shell-code[#:shell 'bash]{raco pkg install peek} to install
       @exec{peek}.}
]


@section{Command Line}

After installing the @exec{peek} package, the launcher is available as
@exec{peek}.

Typical file-preview usage looks like this:

@shellblock[#:shell 'bash]{
peek path/to/file.css
}

When reading from standard input, use @(long-flag "type") to select the
previewer explicitly:

@shellblock[#:shell 'bash]{
cat path/to/file.css | peek --type css
}

To inspect the complete set of explicit file type names:

@shellblock[#:shell 'bash]{
peek --list-file-types
}

Useful command-line combinations:

@shellblock[#:shell 'bash]{
peek -P path/to/file.css
}

@subsection{Options}

General options:

@itemlist[
@item{@DFlag{--type} @italic{type}
    selects the input type explicitly. This is mainly useful for standard
       input. Supported values include @tt{archive}, @tt{binary}, @tt{bash}, @tt{c},
       @tt{cpp}, @tt{css}, @tt{html}, @tt{js}, @tt{json}, @tt{jsx},
       @tt{latex}, @tt{md}, @tt{pascal}, @tt{plist}, @tt{powershell},
       @tt{python}, @tt{rhombus}, @tt{rkt}, @tt{rust}, @tt{scrbl},
       @tt{swift}, @tt{tex}, @tt{wat}, @tt{yaml}, and @tt{zsh}. Use
       @tt{archive} to force archive preview for a supported archive, or use
       @tt{binary} to force the binary preview mode even when automatic
       detection would not select it.}
 @item{@DFlag{--list-file-types}
       prints the currently supported explicit file type names, one per line,
       and exits.}
 @item{@Flag{-a}, @DFlag{--align}
       enables CSS-specific alignment. This may rewrite spacing to improve the
       readability of declarations and aligned rule groups.}
 @item{@DFlag{--no-swatches}
       disables CSS color swatches while keeping syntax coloring enabled.}
 @item{@Flag{-p}, @DFlag{--pretty}
       enables pretty rendering when the selected file type supports it.}
 @item{@DFlag{--pager}
       sends preview output through the configured pager. This is the default
       behavior. @exec{peek} uses the @envvar{PAGER} environment variable when
       it is set, and otherwise falls back to @tt{less -R}.}
 @item{@Flag{-P}, @DFlag{--no-pager}
       writes preview output directly to the terminal instead of opening a
       pager.}
 @item{@DFlag{--color} @litchar{always}@litchar{|}@litchar{auto}@litchar{|}@litchar{never}
       controls ANSI color output. The default is @litchar{always}.}
]

Binary preview options:

@itemlist[
 @item{@(long-flag "bits")
       shows each byte as bits instead of hex digits. This option only affects
       binary previews.}
 @item{@(long-flag "search-bytes") @italic{hex-pattern}
       highlights raw byte sequences in white. Repeat the flag to add more
       patterns. This option only affects binary previews.}
 @item{@(long-flag "search-text") @italic{text}
       highlights UTF-8 text sequences in white. Repeat the flag to add more
       patterns. This option only affects binary previews.}
]

@subsection{Color Modes}

@itemlist[
 @item{@litchar{always} always emits ANSI color and other terminal styling.}
 @item{@litchar{auto} emits color only when the output port is a terminal.}
 @item{@litchar{never} disables color and prints plain text.}
]

@subsection{Pagers}

By default, @exec{peek} opens its output in a pager. Use @Flag{-P} or
@DFlag{--no-pager} when you want @exec{peek} to write directly to the
terminal instead.

By default, @exec{peek} uses:

@itemlist[
 @item{the command named by @envvar{PAGER}, if that environment variable is set}
 @item{@tt{less -R}, otherwise}
]

On Unix-like systems, a common usage is:

@shellblock[#:shell 'bash]{
peek path/to/file.css
}

or, with an explicit pager selection:

@shellblock[#:shell 'bash]{
PAGER="less -R" peek path/to/file.css
}

On Windows, pager availability depends on what is installed. One practical
approach is to point @envvar{PAGER} at an installed pager explicitly. For
example, if @tt{less.exe} is available from Git for Windows:

@shellblock[#:shell 'powershell]{
$env:PAGER = "C:\Program Files\Git\usr\bin\less.exe -R"
peek path\to\file.css
}

If @envvar{PAGER} is not set and @tt{less} is not installed, the default
pager mode will fail with an error instead of silently falling back to plain
output.

@section{Reference}

The current reference sections are:

@itemlist[
 @item{@bold{Web languages:} @seclink["css"]{CSS}, @seclink["html"]{HTML},
       and @seclink["javascript-jsx"]{JavaScript and JSX}}
 @item{@bold{Programming languages:} @seclink["shell"]{Shell},
       @seclink["c"]{C}, @seclink["cpp"]{C++},
       @seclink["objective-c"]{Objective-C}, @seclink["go"]{Go},
       @seclink["haskell"]{Haskell}, @seclink["java"]{Java},
       @seclink["pascal"]{Pascal}, @seclink["python"]{Python},
       @seclink["racket"]{Racket}, @seclink["rhombus"]{Rhombus},
       @seclink["rust"]{Rust}, and @seclink["swift"]{Swift}}
 @item{@bold{Document languages:} @seclink["markdown"]{Markdown},
       @seclink["scribble"]{Scribble}, @seclink["tex"]{TeX}, and
       @seclink["latex"]{LaTeX}}
 @item{@bold{Tooling and config:} @seclink["makefile"]{Makefile}}
 @item{@bold{Data formats:} @seclink["csv"]{CSV}, @seclink["json"]{JSON},
       @seclink["plist"]{Plist}, @seclink["tsv"]{TSV},
       @seclink["wat"]{WAT}, and @seclink["yaml"]{YAML}}
 @item{@bold{Archive files:} @seclink["archive-files"]{Archive Files}}
 @item{@bold{Binary files:} @seclink["binary-files"]{Binary Files}}
]

@subsection{Web Languages}

@subsubsection[#:tag "css"]{CSS}

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

@(input-block cssblock snippet-css)

Rendered CSS preview:

@(preview-shot snippet-css-shot)

@subsubsection[#:tag "html"]{HTML}

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

@(input-block htmlblock snippet-html)

Rendered HTML preview:

@(preview-shot snippet-html-shot)

@subsubsection[#:tag "javascript-jsx"]{JavaScript And JSX}

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

@(input-block jsblock snippet-jsx)

Rendered JavaScript / JSX preview:

@(preview-shot snippet-jsx-shot)

@subsection{Programming Languages}

@subsubsection[#:tag "c"]{C}

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

@(input-block cblock snippet-c)

Rendered C preview:

@(preview-shot snippet-c-shot)

@subsubsection[#:tag "cpp"]{C++}

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

@(input-block cppblock snippet-cpp)

Rendered C++ preview:

@(preview-shot snippet-cpp-shot)

@subsubsection[#:tag "objective-c"]{Objective-C}

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

@(input-block objcblock snippet-objc)

Rendered Objective-C preview:

@(preview-shot snippet-objc-shot)

@subsubsection[#:tag "go"]{Go}

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

@(input-block goblock snippet-go)

Rendered Go preview:

@(preview-shot snippet-go-shot)

@subsubsection[#:tag "haskell"]{Haskell}

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

@(input-block haskellblock snippet-haskell)

Rendered Haskell preview:

@(preview-shot snippet-haskell-shot)

@subsubsection[#:tag "java"]{Java}

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

@(input-block javablock snippet-java)

Rendered Java preview:

@(preview-shot snippet-java-shot)

@subsubsection[#:tag "pascal"]{Pascal}

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

@(input-block pascalblock snippet-pascal)

Rendered Pascal preview:

@(preview-shot snippet-pascal-shot)

@subsubsection[#:tag "python"]{Python}

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

@(input-block pythonblock snippet-python)

Rendered Python preview:

@(preview-shot snippet-python-shot)

@subsubsection[#:tag "racket"]{Racket}

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

@(input-block racketblock snippet-racket)

Rendered Racket preview:

@(preview-shot snippet-racket-shot)

@subsubsection[#:tag "rhombus"]{Rhombus}

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

@(input-block rhombusblock snippet-rhombus)

Rendered Rhombus preview:

@(preview-shot snippet-rhombus-shot)

@subsubsection[#:tag "rust"]{Rust}

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

@(input-block rustblock snippet-rust)

Rendered Rust preview:

@(preview-shot snippet-rust-shot)

@subsubsection[#:tag "swift"]{Swift}

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

@(input-block swiftblock snippet-swift)

Rendered Swift preview:

@(preview-shot snippet-swift-shot)

@subsection{Document Languages}

@subsubsection[#:tag "markdown"]{Markdown}

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

@(input-block markdownblock snippet-markdown)

Rendered Markdown preview:

@(preview-shot snippet-markdown-shot)

@subsubsection[#:tag "scribble"]{Scribble}

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

@(input-scribble snippet-scribble)

Rendered Scribble preview:

@(preview-shot snippet-scribble-shot)

@subsubsection[#:tag "tex"]{TeX}

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

@(input-block texblock snippet-tex)

Rendered TeX preview:

@(preview-shot snippet-tex-shot)

@subsubsection[#:tag "latex"]{LaTeX}

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

@(input-block latexblock snippet-latex)

Rendered LaTeX preview:

@(preview-shot snippet-latex-shot)

@subsection{Tooling and Config}

@subsubsection[#:tag "makefile"]{Makefile}

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

@(input-block makefileblock snippet-makefile)

Rendered Makefile preview:

@(preview-shot snippet-makefile-shot)

@subsubsection[#:tag "shell"]{Shell}

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

@(input-shell snippet-shell 'bash)

Rendered shell preview:

@(preview-shot snippet-shell-shot)

@subsection{Data Formats}

@subsubsection[#:tag "csv"]{CSV}

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

@(input-block csvblock snippet-csv)

Rendered CSV preview:

@(preview-shot snippet-csv-shot)

@subsubsection[#:tag "json"]{JSON}

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

@(input-block jsonblock snippet-json)

Rendered JSON preview:

@(preview-shot snippet-json-shot)

@subsubsection[#:tag "plist"]{Plist}

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

@(input-block plistblock snippet-plist)

Rendered Plist preview:

@(preview-shot snippet-plist-shot)

@subsubsection[#:tag "tsv"]{TSV}

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

@(input-block tsvblock snippet-tsv)

Rendered TSV preview:

@(preview-shot snippet-tsv-shot)

@subsubsection[#:tag "wat"]{WAT}

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

@(input-block wasmblock snippet-wat)

Rendered WAT preview:

@(preview-shot snippet-wat-shot)

@subsubsection[#:tag "yaml"]{YAML}

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

@(input-block yamlblock snippet-yaml)

Rendered YAML preview:

@(preview-shot snippet-yaml-shot)

@subsection[#:tag "archive-files"]{Archive Files}

For Archive Files, @exec{peek} currently supports:

@itemlist[
 @item{tree previews for @tt{.zip}, @tt{.tar}, @tt{.tgz}, and @tt{.tar.gz}}
 @item{automatic archive routing from those known extensions}
 @item{explicit @tt{archive} mode for stdin and files}
 @item{an explicit escape hatch to raw bytes with @tt{binary} mode}
]

The archive previewer is intentionally structural. It renders the archive as
a directory tree instead of raw bytes. ZIP previews use Racket's
@racketmodname[file/unzip] directory-reading support, while TAR and
TGZ/TAR.GZ previews use the @racketmodname[file/untar] path/filter pipeline
to collect entries without unpacking files to disk.

Example archive preview command:

@shellblock[#:shell 'bash]{
peek archive.zip
}

@subsection[#:tag "binary-files"]{Binary Files}

For Binary, @exec{peek} currently supports:

@itemlist[
 @item{hex-style previewing for arbitrary binary data}
 @item{explicit @tt{binary} mode for stdin and files}
 @item{@(long-flag "bits") to show each byte as bits instead of hex digits}
 @item{@(long-flag "search-bytes") to highlight raw byte sequences in white}
 @item{@(long-flag "search-text") to highlight UTF-8 text sequences in white}
 @item{automatic fallback to binary when unknown input looks non-textual}
]

The binary previewer is intentionally hex-oriented by default. It shows
offsets, color groups for bytes, and an ASCII gutter, and @(long-flag "bits") swaps
the byte cells to 8-bit binary strings. @(long-flag "search-bytes") highlights the
matched bytes in white, and each pattern can be expressed as one hex string
such as @tt{4243}; repeat the flag to add more patterns. @(long-flag "search-text")
highlights UTF-8 text sequences in white, and each pattern is a normal text
string; repeat the flag to add more patterns. The previewer does not try to
interpret the bytes as structured text.

The file @filepath{all-bytes.bin} used below contains the byte values
@tt{00} through @tt{FF} in order. @exec{peek} can detect binary files
automatically, which is why the first command omits an explicit type. When
needed, you can still force binary rendering with @(long-flag "type")
@tt{binary}.

Commands used for the binary preview examples:

@(input-shell snippet-binary 'bash)

Result of @exec{peek all-bytes.bin}:

@(preview-shot snippet-binary-shot-1)

Result of @exec{peek --search-bytes 42 all-bytes.bin}:

@(preview-shot snippet-binary-shot-2)

Result of @exec{peek --search-bytes 4243 --search-bytes c0 all-bytes.bin}:

@(preview-shot snippet-binary-shot-3)

Result of @exec{peek --search-text bcd all-bytes.bin}:

@(preview-shot snippet-binary-shot-4)

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
