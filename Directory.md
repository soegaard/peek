# Directory Preview Design Notes

Directory preview is a generic path-based preview rather than an explicit
language previewer.

Current behavior:

- directory paths are detected from the path itself
- the output is a flat, `ls`-like listing
- directories come first, then links, then regular files
- regular-file sizes are right-aligned
- blank lines separate the directory, link, and file groups
- `--kind` groups regular files by file kind such as `.md` or `.rkt`
- `--size` sorts regular files by descending size

This feature is intentionally narrower than a real `ls` replacement. The goal
is to give a quick structural overview of a folder while staying terminal-first
and easy to scan.
