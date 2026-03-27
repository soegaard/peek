#lang scribble/manual

@(require scribble-tools
          (for-label lexers/css
                     racket/base
                     peek/main
                     peek/preview))

@title{peek}
@defmodule[peek/main]

@para{
@exec{peek} is a terminal-first preview tool for files and standard input.
It is intentionally small: @exec{peek} does not try to replace a pager or a
general-purpose file viewer. Instead, it provides file-type-aware terminal
previewing for supported file types.
}

@para{
CSS is the first supported file type. The CSS previewer uses
@tt{lexers/css} for lexing and adds terminal-oriented rendering
features such as syntax coloring, color swatches, and optional alignment.
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

@section{Library}

The command-line tool is backed by a small library in
@racketmodname[peek/preview].

@defmodule[peek/preview]

@defstruct*[preview-options
            ([type (or/c symbol? #f)]
             [align? boolean?]
             [swatches? boolean?]
             [color-mode symbol?])]{
Shared preview configuration for both @racket[preview-string] and
@racket[preview-file].
}

@defproc[(make-preview-options
          [#:type type (or/c symbol? #f) #f]
          [#:align? align? boolean? #f]
          [#:swatches? swatches? boolean? #t]
          [#:color-mode color-mode symbol? 'always])
         preview-options?]{
Construct preview options for @racket[preview-string] and
@racket[preview-file].
}

@defproc[(preview-string [source string?]
                         [maybe-path (or/c path-string? #f) #f]
                         [options preview-options? (make-preview-options)]
                         [out output-port? (current-output-port)])
         string?]{
Preview @racket[source] using the selected options.
}

@defproc[(preview-file [path path-string?]
                       [options preview-options? (make-preview-options)]
                       [out output-port? (current-output-port)])
         string?]{
Read and preview a file from disk.
}

@defmodule[peek/main]
@defproc[(main) void?]{
Run the @exec{peek} command-line interface.
}

@section{Notes}

Unsupported file types currently fall back to plain text.

The initial implementation focuses on CSS and a small generic preview
pipeline. Future file types may add their own previewers without forcing all
file types into the same rendering model.
