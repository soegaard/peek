#lang scribble/manual

@(require scribble-tools
          (for-label lexers/css
                     racket/base
                     (lib "peek/main.rkt")
                     (lib "peek/preview.rkt")))

@title{peek}
@defmodule[(lib "peek/main.rkt")]

@para{
@exec{peek} is a terminal-first preview tool for files and standard input.
It is intentionally small: @exec{peek} does not try to replace a pager or a
general-purpose file viewer. Instead, it provides file-type-aware terminal
previewing for supported file types.
}

@para{
CSS and JavaScript are currently supported. The CSS previewer uses
@tt{lexers/css} for lexing and adds terminal-oriented rendering
features such as syntax coloring, color swatches, and optional alignment.
The JavaScript previewer uses @tt{lexers/javascript}, and enables JSX-aware
classification for @tt{.jsx} files.
}

@section{Command Line}

After installing the @exec{peek} package, the launcher is available as
@exec{peek}.

@shellblock[#:shell 'bash]{
peek path/to/file.css
}

When reading from standard input, use @DFlag{--type} to select the file type:

@shellblock[#:shell 'bash]{
cat path/to/file.css | peek --type css
}

Useful CSS examples:

@shellblock[#:shell 'bash]{
peek --align path/to/file.css
peek --no-swatches path/to/file.css
peek --color never path/to/file.css
peek --color auto path/to/file.css | less -R
}

JavaScript and JSX examples:

@shellblock[#:shell 'bash]{
peek path/to/file.js
peek path/to/component.jsx
}

@subsection{Options}

@itemlist[
 @item{@DFlag{--type} @italic{type}
       selects the input type explicitly. This is mainly useful for standard
       input. The initial useful value is @racket['css].}
 @item{@DFlag{--align}
       enables CSS-specific alignment. This may rewrite spacing to improve the
       readability of declarations and aligned rule groups.}
 @item{@DFlag{--no-swatches}
       disables CSS color swatches while keeping syntax coloring enabled.}
 @item{@DFlag{--color} @litchar{always}@litchar{|}@litchar{auto}@litchar{|}@litchar{never}
       controls ANSI color output. The default is @litchar{always}.}
]

@subsection{Color Modes}

@itemlist[
 @item{@litchar{always} always emits ANSI color and other terminal styling.}
 @item{@litchar{auto} emits color only when the output port is a terminal.}
 @item{@litchar{never} disables color and prints plain text.}
]

@section{Supported File Types}

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

@section{Library}

The command-line tool is backed by a small library in
@racketmodname[(lib "peek/preview.rkt")].

The initial library surface is intentionally small:

@itemlist[
 @item{@tt{make-preview-options} constructs a preview-options value with
       optional type, alignment, swatch, and color-mode settings.}
 @item{@tt{preview-string} previews a source string using the selected
       options.}
 @item{@tt{preview-file} reads a file and previews it using the selected
       options.}
]

The command-line entry point lives in
@racketmodname[(lib "peek/main.rkt")] and is exported as @tt{main}.

@section{Notes}

Unsupported file types currently fall back to plain text.

The current implementation focuses on CSS, JavaScript, and a small generic
preview pipeline. Future file types may add their own previewers without
forcing all file types into the same rendering model.
