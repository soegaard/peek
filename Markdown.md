# Markdown Design Notes

## Source Of Truth

The Markdown previewer uses `lexers/markdown` as its source of truth.

The current lexer implements GitHub Flavored Markdown, but `peek` exposes the
generic explicit file type name `md` for now. Future Markdown variants may add
new explicit type names later without changing the current meaning of `md`.

## Rendering Model

The first Markdown pass is syntax coloring only.

`peek` does not attempt to render Markdown as a formatted document. Ordinary
Markdown prose remains plain. Structural markers such as headings, list
markers, task markers, blockquote markers, fences, and table pipes are colored
as syntax.

Inline code, code fences, links, autolinks, and table payloads are colored
using the existing terminal palette, but Markdown support does not add layout
rewriting, table formatting, or other presentation transforms in this pass.

## Embedded Languages

The Markdown lexer can delegate recognized embedded regions to other lexers.

`peek` should reuse the existing file-type color model for delegated regions:

- embedded HTML uses the HTML style mapping
- embedded CSS uses the CSS style mapping
- embedded Java uses the Java style mapping
- embedded JavaScript uses the JavaScript style mapping
- embedded C++ uses the C++ style mapping
- embedded Go uses the Go style mapping
- embedded Haskell uses the Haskell style mapping
- embedded Racket uses the Racket style mapping
- embedded Swift uses the Swift style mapping
- embedded Scribble uses the Scribble style mapping

`peek` should not parse fenced code info strings or raw HTML itself. Delegation
is driven entirely by the embedded-language tags exposed by `lexers/markdown`.
