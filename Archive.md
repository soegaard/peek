# Archive Preview Notes

`peek` treats archive preview as a separate preview family from both text
preview and binary preview.

The first supported archive formats are:

- `zip`
- `tar`
- `tgz` / `tar.gz`

The archive previewer renders a directory tree instead of raw bytes. That
keeps the output terminal-first while answering the most common archive
question quickly: “what is in here?”

Current design choices:

- archive detection is extension-first, with a small amount of byte-level
  recognition for fallback cases
- explicit `--type archive` forces archive preview
- explicit `--type binary` remains the escape hatch for raw byte inspection
- ZIP uses Racket’s `file/unzip` directory-reading API
- TAR and TGZ use Racket’s `file/untar` path/filter pipeline

The first version prefers structural preview over metadata completeness.
ZIP previews currently show the tree and entry counts, but do not try to
recover per-entry sizes through non-public APIs.
