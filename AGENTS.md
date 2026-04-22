# AGENTS.md

The repo contains `peek`, a tool for previewing files in the terminal.

The first supported file type is CSS.
The CSS previewer should use the lexer from `lexers/css`.
Future file types may be added later.

- When given rules, always ask whether they should be added to `AGENTS.md`.

Guidelines

1. Keep the tool terminal-first.
2. Prefer simple designs with clear data flow.
3. Prefer reuse of `lexers` over reimplementing lexing logic locally.
4. Keep file-type-specific logic separated from generic preview logic.
5. Preserve useful source information from lexers, especially token categories and source positions, when it improves previews or diagnostics.
6. When a preview needs to recover from malformed input, prefer best-effort output over crashing.
7. Add tests for preview behavior with realistic sample inputs.
8. Keep public behavior easy to inspect from the terminal.
9. Document design decisions in `DESIGN.md` when they affect future file-type support or the division between generic and file-type-specific code.
10. `peek` should support a pager mode via `-p` / `--pager`, which sends rendered output through `less -R`.
10. When preview rendering inserts visible elements such as swatches, alignment must use rendered width, including the visible width of inserted elements.
11. Put shared design notes in `DESIGN.md`; put file-type-specific design notes in files such as `CSS.md`.
12. Default preview output should keep color enabled unless the user explicitly disables it.
13. `peek` should support `--list-file-types` to print the currently supported explicit file type names.
14. Persistent smoke tests and fixtures belong in `test/`, not in `tmp/`, which is for temporary local files.
15. Racket-family files with extensions `.rkt`, `.ss`, `.scm`, and `.rktd` should use the Racket previewer.
16. When a preview issue appears to stem from a lexer token stream rather than `peek`, call that out explicitly so the lexer can be fixed at the source.
17. Standalone WAT preview should support true streaming for very large files.
18. Corpus round-trip tests should enforce a hard 2-minute timeout per file and report the file that timed out.
18. Markdown and JavaScript corpus round-trip tests should enforce a hard 1-minute timeout per file and report the file that timed out.


Coding guidelines for Racket code.

1. Prefer `cond` over nested `if`/`let` patterns when branching logic is non-trivial.
2. Prefer internal `define` inside `cond` branches instead of wrapping branch bodies in `let` or `let*`.
3. Align right-hand-side expressions when it improves readability.
4. Avoid hanging parentheses; keep closing `))` on the same line as the final expression.
5. Prefer named struct fields over numeric indices.
6. Add function comments for helpers and exported functions:
   - `;; name : contract -> result`
   - `;;   Brief purpose sentence.`
7. Add inline comments for parameter types and optional/default parameters when relevant.
8. Add a comment header before blocks of constant definitions.
9. If a constant/definition name is not self-explanatory, add an end-of-line comment explaining its meaning/purpose.
10. When symbols are used for enumeration, use `case` instead of `cond` for branching.
11. At the top of each file, add a header comment in this form:
    - `;;;`
    - `;;; Title`
    - `;;;`
    - ``
    - `;; An explanation of the contents of the source file.`
12. Use `for` constructs instead of explicit loops.
13. Use `match` for destructuring.
14. For each file export, add a comment near the top (after the header
    and file explanation) with the export identifier and a one-line
    explanation; align the start of the explanations.
15. If you find an error in other libraries/folder than this repo:
    First make a minimal reproduction of the error, then ask
    how to proceed.
16. Do not add workaroundsinvestigate and fix the root cause instead.
    Ask for help if needed.

17. Use `rackunit` for tests.
18. For consecutive calls with the same callee and simple arguments, align argument columns to improve scanability.


Packages

There are 3 packages:

  - peek-lib   The implementation of peek
  - peek-doc   The documentation of the peek written in Scribble
  - peek       Installs both peek-lib and peek-doc


Scribble

Build the manual with:

  - `raco scribble +m --htmls --dest html/ peek-doc/peek.scrbl`

When writing Scribble prose, use `@"@"` to quote a single `@`.




## Design Notes

1. Shared design notes are in `DESIGN.md`.
2. Each supported file type should keep its specific design notes in its own file, such as `CSS.md`, `HTML.md`, `JS.md`, `Markdown.md`, `Racket.md`, `Scribble.md`, or `WAT.md`.
