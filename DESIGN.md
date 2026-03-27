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
  - output-mode decisions such as tty vs non-tty behavior

- File-type preview layer
  - token interpretation for a specific file type
  - file-type-specific rendering decisions
  - optional layout enhancements that are meaningful for that file type

This separation is important for future file-type support. File-type-specific
concepts must stay in the corresponding previewer and not leak into the generic
preview path.

## Design Notes By File Type

Shared notes belong in this file.

File-type-specific notes belong in separate files, such as:

- [`CSS.md`](/Users/soegaard/Dropbox/GitHub/peek/CSS.md)
