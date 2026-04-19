# peek-lib

`peek-lib` is the implementation package for `peek`.

It keeps the runtime footprint small and contains the terminal preview logic
for supported file types. The documentation package is split out separately as
`peek-doc`.

## Contents

- the preview dispatcher
- file-type-specific terminal renderers
- command-line support code shared by the launcher
- regression tests and corpus tests

## Dependency policy

`peek-lib` intentionally avoids documentation dependencies such as Scribble.
It only depends on the libraries needed to implement and test the previewer.

