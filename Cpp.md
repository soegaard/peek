# C++ Design Notes

## Source Of Truth

The C++ previewer uses `lexers/cpp` as its source of truth.

`peek` exposes the explicit file type name `cpp` for standalone C++ sources.

## Rendering Model

The first C++ pass is syntax coloring only.

`peek` does not attempt to infer build systems, compiler flags, or project
metadata. The previewer keeps source text and line breaks intact and only adds
ANSI color to lexical roles that help terminal inspection.

## Supported Files

C++ preview currently targets common C++ source and header extensions such as
`.cpp`, `.cc`, `.cxx`, `.cp`, `.c++`, `.cppm`, `.ixx`, `.hpp`, `.hh`, `.hxx`,
`.h++`, `.ipp`, and `.tpp`.

## Embedded C++

Markdown fenced code blocks labeled `cpp`, `c++`, `cc`, `cxx`, `hpp`, `hh`, or
`hxx` delegate to `lexers/cpp`. `peek` should reuse the same C++ style mapping
for those delegated regions so embedded previews stay consistent with
standalone C++ files.
