# Plist Design Notes

The plist previewer uses `lexers/plist` as its source of truth.

The first pass targets XML property-list files such as `Info.plist`.
It does not attempt to cover binary `bplist` files.

The plist previewer is intentionally color-only. It preserves source text
and line breaks without layout rewriting.

`peek` colors plist doctype and tag syntax, attribute names, attribute
values, keys, string/data/date/integer/real text, comments, and malformed
input with best-effort recovery.

Plist preview uses the port-oriented streaming path.

That means large plist files and stdin input can be previewed without first
materializing the whole source as a string.
