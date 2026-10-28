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

Binary input is a special fallback case rather than a text-language preview.
The generic layer may classify an unknown input as likely binary and route it
to a hex-oriented renderer that shows offsets, bytes, and an ASCII gutter
instead of attempting text rendering.
The binary previewer also has a bit-oriented mode, selected with `--bits`,
that keeps the same layout but renders each byte as an 8-bit binary string
instead of hexadecimal digits.
It can also highlight a raw byte sequence in white via `--search-bytes`,
which is useful when scanning for a known marker or magic number. It can also
highlight UTF-8 text sequences in white via `--search-text`. Repeat either
flag to highlight multiple sequences.

Archive input is another special generic case. For supported archive formats,
the generic layer routes to an archive tree preview instead of either text
rendering or raw binary rendering. This keeps archive support separate from
language previewers while still letting `--type binary` act as an explicit
raw-byte override when needed.

Directory input is another path-oriented generic case. When the input path is
a directory, the generic layer routes to a flat directory preview instead of
treating the path as a file. This preview stays intentionally close to `ls`:
directories appear first, links next, regular files after that, regular-file
sizes are aligned, and optional sorting can group by file kind or by size.
`--stats` builds on the same path-oriented layer and appends a compact summary
block instead of creating a separate stats-only preview mode. That keeps
folder preview separate from both archive trees and text-language previewers
while still sharing one summary format with archive preview.

Git-focused diff preview is another generic path-oriented layer. `--diff`
does not try to replace `git diff`; instead, it asks Git for the changed
working-tree hunks for one file and reuses the normal file-type previewer on
the visible hunk lines. Context, removed, and added lines are preserved as
separate diff rows, which keeps deleted lines visible without turning `peek`
into a full patch viewer. The current design is intentionally file-path-only
and buffered, so ordinary file preview keeps its fast port-to-port streaming
path while diff preview remains simple and predictable.

## Following Files

`--follow` renders the initial file content and each appended byte batch through
the normal port-based preview pipeline. It keeps the generic line-number,
range, and grep wrappers open across batches, while each language renderer gets
a finite batch and can flush its final line immediately. A permanently open
input stream would preserve lexer state, but some lexers defer their final
newline until more input arrives, which makes a terminal preview appear one
line behind.

Follow mode is intentionally limited to regular text previews. Directory,
archive, binary, diff, statistics, and Markdown-outline modes either need a
finite input or have path-oriented semantics that do not describe a growing
text stream.

## Assembly Source

Assembly previewing uses the shared, byte-preserving `lexers/asm` derived-token
interface; `peek` applies only terminal presentation and never tokenizes an
assembly dialect itself. Assembly suffixes (`.asm`, `.s`, `.S`, `.sx`, and
`.nasm`) start bounded content probing. Ambiguous `.inc`, `.i`, and `.a` input,
extensionless files, and stdin need sufficiently strong profile evidence before
they take the assembly path; unresolved includes retain Pascal previewing.

The lexer’s calibration gate is authoritative. `peek` adopts an automatically
detected dialect only when the probe marks that profile qualified. A plausible
but unqualified assembly sample uses the neutral generic profile, rather than
claiming a CPU, assembler dialect, or executable identity. `--type asm` remains
an explicit generic choice unless `--dialect` (and, for GNU syntax, `--arch`) is
also supplied.

Before the renderer starts, `peek` samples at most 32 KiB or 256 physical
lines and prepends that exact sample to the unconsumed input. The normal
`interactive` schedule waits at most 20 ms for more input after data arrives;
`--detection-mode fixed-prefix` instead waits for EOF or a cap, giving scripts
a reproducible bounded prefix. UTF-16 BOMs are recognized before NUL-byte
binary routing. Strong binary or archive evidence routes to a safe
representation preview even when assembly was explicitly requested. Ordinary
source preview stays port-oriented and flushes fragments promptly; `--grep`
retains its existing whole-rendered-line buffer.

The generic renderer safely escapes terminal-active controls, malformed source
bytes, and lone carriage returns regardless of color mode. CRLF renders as a
single newline. `--follow` is deliberately unavailable for assembly until the
shared lexer exposes a stateful feed/checkpoint API. `--detect-only --json`,
`--explain-type`, and `--dump-tokens jsonl` expose bounded selection facts and
raw-byte token fragments. Detection JSON includes candidates, evidence,
conflicts, scores, the calibration decision, and the actual renderer fallback.

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
- [`Java.md`](/Users/soegaard/Dropbox/GitHub/peek/Java.md)
- [`JS.md`](/Users/soegaard/Dropbox/GitHub/peek/JS.md)
- [`JSON.md`](/Users/soegaard/Dropbox/GitHub/peek/JSON.md)
- [`Go.md`](/Users/soegaard/Dropbox/GitHub/peek/Go.md)
- [`Haskell.md`](/Users/soegaard/Dropbox/GitHub/peek/Haskell.md)
- [`Makefile.md`](/Users/soegaard/Dropbox/GitHub/peek/Makefile.md)
- [`Plist.md`](/Users/soegaard/Dropbox/GitHub/peek/Plist.md)
- [`Pascal.md`](/Users/soegaard/Dropbox/GitHub/peek/Pascal.md)
- [`Binary.md`](/Users/soegaard/Dropbox/GitHub/peek/Binary.md)
- [`Archive.md`](/Users/soegaard/Dropbox/GitHub/peek/Archive.md)
- [`Assembly.md`](/Users/soegaard/Dropbox/GitHub/peek/Assembly.md)
- [`Directory.md`](/Users/soegaard/Dropbox/GitHub/peek/Directory.md)
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
