# `peek` Design Notes

## Purpose

`peek` is a terminal-first preview tool for files and stdin. It is intentionally
narrower than general-purpose terminal viewers such as `bat`: it is not trying
to replace `cat`, `less`, or a pager-based source browser. Instead, `peek`
provides a small generic preview pipeline and lets each supported file type
supply its own terminal presentation.

This keeps the design simple and makes it possible to add file-type-specific
behavior that would not make sense as a universal viewer feature.

## Architecture

The implementation is divided into two layers:

- Generic preview layer
  - input loading from file or stdin
  - file-type detection
  - dispatch to a file-type previewer
  - plain-text fallback for unsupported types
  - output-mode decisions such as color mode and tty detection

- File-type preview layer
  - token interpretation for a specific file type
  - file-type-specific rendering decisions
  - optional layout enhancements that are meaningful for that file type

This separation is important for future file-type support. File-type-specific
concepts must stay in the corresponding previewer and not leak into the generic
preview path.

The generic layer now has two rendering shapes:

- buffered previewing, where the whole input is materialized as a string and a
  previewer returns a rendered string
- port-oriented previewing, where a previewer writes directly to an output port

Most current file types now use the port-oriented path. CSS remains the main
buffered/special-case renderer because it may insert swatches and alignment.
WAT keeps the streaming focus for very large standalone inputs. This keeps the
generic architecture forward-compatible without forcing every file type through
a single rendering model.

## Lessons From `scribble-tools`

The JavaScript colorer in `scribble-tools` is a useful reference point for
future file-type support, but it should be treated primarily as architectural
prior art, not as an implementation template for `peek`.

The main lesson worth borrowing is the layered pipeline:

- tokenize
- add semantic annotations
- render

That layering makes it possible to keep rendering concerns separate from
language analysis, while still letting a file-type previewer enrich raw tokens
with roles that improve the final output.

For `peek`, this means future previewers may add a file-type-specific
annotation pass when lexer output alone is not enough for a good terminal
preview.

The parts that should not be copied directly are the pieces that are specific
to documentation rendering rather than terminal previewing. In particular:

- do not introduce custom tokenizers when the corresponding `lexers` module is
  sufficient
- do not mix documentation-link inference into the terminal renderer
- do not pull Scribble-specific rendering concerns into generic preview code

So the intended direction for future file types is:

- start from the corresponding `lexers` module
- preserve useful token and position information
- add a small file-type-specific semantic pass only when it materially improves
  terminal output
- keep rendering terminal-first

## Design Notes By File Type

Shared notes belong in this file.

File-type-specific notes belong in separate files, such as:

- [`CSS.md`](/Users/soegaard/Dropbox/GitHub/peek/CSS.md)
- [`C.md`](/Users/soegaard/Dropbox/GitHub/peek/C.md)
- [`Cpp.md`](/Users/soegaard/Dropbox/GitHub/peek/Cpp.md)
- [`ObjC.md`](/Users/soegaard/Dropbox/GitHub/peek/ObjC.md)
- [`Delimited.md`](/Users/soegaard/Dropbox/GitHub/peek/Delimited.md)
- [`HTML.md`](/Users/soegaard/Dropbox/GitHub/peek/HTML.md)
- [`JS.md`](/Users/soegaard/Dropbox/GitHub/peek/JS.md)
- [`JSON.md`](/Users/soegaard/Dropbox/GitHub/peek/JSON.md)
- [`Haskell.md`](/Users/soegaard/Dropbox/GitHub/peek/Haskell.md)
- [`Makefile.md`](/Users/soegaard/Dropbox/GitHub/peek/Makefile.md)
- [`Plist.md`](/Users/soegaard/Dropbox/GitHub/peek/Plist.md)
- [`Pascal.md`](/Users/soegaard/Dropbox/GitHub/peek/Pascal.md)
- [`Python.md`](/Users/soegaard/Dropbox/GitHub/peek/Python.md)
- [`TeX.md`](/Users/soegaard/Dropbox/GitHub/peek/TeX.md)
- [`LaTeX.md`](/Users/soegaard/Dropbox/GitHub/peek/LaTeX.md)
- [`Markdown.md`](/Users/soegaard/Dropbox/GitHub/peek/Markdown.md)
- [`Racket.md`](/Users/soegaard/Dropbox/GitHub/peek/Racket.md)
- [`Rhombus.md`](/Users/soegaard/Dropbox/GitHub/peek/Rhombus.md)
- [`Rust.md`](/Users/soegaard/Dropbox/GitHub/peek/Rust.md)
- [`Shell.md`](/Users/soegaard/Dropbox/GitHub/peek/Shell.md)
- [`Swift.md`](/Users/soegaard/Dropbox/GitHub/peek/Swift.md)
- [`Yaml.md`](/Users/soegaard/Dropbox/GitHub/peek/Yaml.md)
- [`Scribble.md`](/Users/soegaard/Dropbox/GitHub/peek/Scribble.md)
- [`WAT.md`](/Users/soegaard/Dropbox/GitHub/peek/WAT.md)
