# Binary Preview Notes

The binary previewer is a fallback renderer for non-text input.

It intentionally shows a hex view instead of trying to guess a structured
format. The first pass is conservative:

- explicit `binary` mode always uses the hex view
- `--bits` switches the binary view to bit cells instead of hex cells
- `--search-bytes` highlights byte sequences in white; pass each pattern as
  one hex string and repeat the flag to add more patterns
- `--search-text` highlights UTF-8 text sequences in white; pass each pattern
  as a normal UTF-8 string and repeat the flag to add more patterns
- unknown input may fall back to binary when it looks non-textual
- plain text still stays in the text-oriented preview paths

The rendered layout is hex-oriented and terminal-first:

- byte offsets on the left
- color-coded byte groups in the middle
- an ASCII gutter on the right

The current palette follows the article-style 18-swatch scheme. Zero bytes are
subtle, 255 gets its own accent, and the remaining bytes use the swatches
shown in the palette image so large blobs still show structure in the terminal.
