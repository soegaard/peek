# Assembly support: rules and implementation plan

Status: generic assembly support is implemented through M3, and `peek`'s M7
integration is implemented as of 2026-10-28. The shared M0–M1 source/lexer
contract and M7 probe live in the sibling `lexers` checkout; `peek` performs
bounded input preparation, safe content arbitration, calibrated-profile routing,
and inspection. A plausible but unqualified probe result deliberately retains
the generic renderer; it will adopt an exact profile only when `lexers` marks
that profile calibration-qualified.

This document interprets the supplied **Assembly support design for peek.md**
as design input. Its imperative wording is not authorization to execute build
scripts, acquire corpora, change another repository, or implement every phase
immediately. The current request is to produce this plan and keep the assembly
rules in a separate document.

The source design is at
`/Users/soegaard/Downloads/Assembly support design for peek.md`. Its external
syntax references and license observations have not been independently audited
in this planning task. Verify the relevant primary specifications and selected
fixture notices when implementing each profile.

## 1. Recommended scope and order

Build a reusable `lexers/asm` implementation first, followed by a thin terminal
renderer in `peek`. Ship useful forced selection before enabling automatic
dialect selection. Keep CPU identity, source language, and binary format
independent throughout.

The first implementation milestone is **M0–M3 below**: contracts, byte-preserving
streaming, generic assembly rendering, bounded representation checks, and
inspection. M4–M6 add the priority dialects. M7 enables automatic selection only
for profiles that pass the detection gates. M8 is later expansion.

The dependencies are:

```text
M0 contracts and fixtures
  -> M1 shared source/lexer foundation
  -> M2 bounded input preparation and representation routing
  -> M3 peek rendering, forced selection, inspection, first usable release
  -> M4 ca65 / ACME / native Motorola
  -> M5 Kick / 64tass / native refinements
  -> M6 GNU m68k / x86 / ARM / AArch64 and NASM
  -> M7 calibrated automatic selection, enabled per profile
  -> M8 additional dialects and separate representation adapters
```

Detector infrastructure and corpus collection start in M0, so M7 does not
require redesigning completed lexers. M4, M5, and M6 share the M1 contract;
their ordering expresses delivery priority, not a technical dependency between
unrelated CPU families. This plan does not require parallel agents.

## 2. Assembly rules

These rules supplement the repository's existing `AGENTS.md` conventions.

1. **Own the grammar in `lexers`.** The detector and renderer must share the
   same assembly language definitions. Do not introduce a second tokenizer or
   a local lexer workaround in `peek`.
2. **Keep classification dimensions separate.** Represent artifact kind,
   architecture, CPU variant/features, instruction mode, syntax, dialect,
   implementation/version, processing layers, platform/ABI, actual binary
   format, source output intent, and source encoding/container independently.
   Validate combinations against a profile's capabilities.
3. **Permit uncertainty.** Unknown, ambiguous, conflicting, conditional, and
   unsupported results are valid. Compatible source is not proof of a
   particular assembler executable, version, CPU variant, or output format.
4. **Preserve authoritative bytes.** Token fragments must partition the input
   exactly, including BOMs, whitespace, original newlines, invalid sequences,
   and a missing final newline. Keep byte spans separate from Racket positions,
   decoded character positions, and terminal columns.
5. **Stream with bounded storage.** Bound the probe, token fragments, lexical
   lookahead, conditional alternatives, nesting, caches, and diagnostics.
   A port API that buffers an entire token or line is insufficient.
6. **Use profile-specific lexical states.** Comments, strings, labels, macro
   parameters, case rules, and preprocessing differ between dialects and CPU
   targets. CPU tables alone do not define an assembler language.
7. **Respect state changes and their context.** Apply source syntax/mode
   changes locally. Do not execute a directive inside an unexpanded macro as
   a file-level change. Join conditional branches conservatively.
8. **Recover without losing source.** Unknown instructions and macros are not
   automatically errors. Malformed input yields preserved fragments and bounded
   diagnostics. Every non-EOF step must consume input or report a genuine
   need for more input.
9. **Keep presentation separate.** Escape terminal-active source controls and
   undecodable bytes for display. Preserve original bytes through the lexer
   and inspection interfaces. Disabling color does not disable escaping.
10. **Honor explicit choices.** Record them as forced, not as confidence 100.
    Reject contradictory explicit dimensions. Source disagreements produce
    diagnostics without silently changing the forced dialect.
11. **Treat suffixes as hints.** Preserve extension case. `.S` does not prove
    CPP; `.inc` does not prove assembly; `.a` may be source or an archive.
    Binary objects, listings, disk images, and tokenized source have separate
    input paths.
12. **Do not execute source during preview.** Do not expand macros, invoke CPP
    or assemblers, run build scripts, load source-selected plugins, or traverse
    arbitrary includes. Declarative configuration must be explicitly enabled.
13. **Freeze automatic selection before ordinary output.** Later evidence may
    produce diagnostics; it cannot recolor an emitted prefix. Genuine in-file
    language switches remain supported.
14. **Keep decisions inspectable.** Explanations go to stderr. Detection JSON
    and token JSONL are explicit output modes with stable, versioned schemas.
15. **Use realistic tests and provenance.** Keep persistent `peek` tests and
    fixtures under `peek-lib/peek/test/`. Use RackUnit. Every assembly corpus
    file has a hard 120-second deadline and failures identify the file/profile.
16. **Preserve existing terminal behavior.** Default color stays enabled;
    `--pager` continues to support `less -R`; `--list-file-types` stays the
    canonical spelling. Any inserted visible text participates in width
    calculations.
17. **Document the proper boundary.** Shared preview decisions belong in
    `DESIGN.md`; assembly decisions belong here. Public behavior belongs in
    `peek-doc/peek.scrbl`; reusable lexer APIs also require `lexers-doc` updates.
18. **Fix causes at their owner.** If an existing external lexer/library defect
    is discovered, first make a minimal reproduction, then ask how to proceed,
    as required by `AGENTS.md`. Missing assembly functionality is a planned
    dependency, not evidence of an existing defect.

For Racket implementation, retain the repository's header/export/helper
comments, named fields/accessors, `match`, `case` for enumerations, `cond` with
internal definitions, `for` forms where appropriate, aligned simple calls, and
RackUnit conventions. Do not copy numeric struct-field access from older
previewers into the assembly implementation.

## 3. Current code and implications

Inspection baseline: `peek` commit `a035a72`, sibling `lexers` commit `d1399bc`.
Both working trees were clean before this document was added. The installed
`lexers/c` resolves to the sibling checkout at
`/Users/soegaard/Dropbox/GitHub/lexers/lexers-lib/lexers/c.rkt`.

| Existing code | Finding and implementation consequence |
| --- | --- |
| `peek-lib/peek/main.rkt` | Owns CLI parsing, pager selection, and `make-preview-options`. Add selection/inspection options here; machine-readable output must bypass the pager. |
| `peek-lib/peek/preview.rkt` | Owns type selection, string/port/file entry points, output wrappers, diff, and follow. Assembly must reach every relevant entry point. |
| `detect-file-type` | Mostly suffix-based; `.inc` currently selects Pascal. Introduce content-aware arbitration without making all includes assembly. |
| `preview-port` | Unknown input currently falls through to `port->bytes`; recognized languages run before the binary fallback. Assembly probing cannot reuse that whole-input path. |
| `preview-string/rendered` and no-color branches | Several paths return/copy source directly. Assembly escaping and diagnostics must still run with `--color never`. |
| `preview-options` | Its positional constructor is public. Adding fields blindly would break callers. Preserve that API while introducing assembly configuration. |
| `follow-render-options` and `preview-follow-path` | Copy options and restart a renderer on each finite appended batch. That would lose assembly syntax, macro, and decoder state. |
| Diff helpers | Render full current-file lines in some cases and isolated old/hunk snippets in others. A snippet may lack the state needed for correct assembly coloring. |
| `make-grep-output-port` | Buffers whole rendered lines. The default assembly stream can be bounded while `--grep` retains line buffering; document and measure this distinction. |
| `peek-lib/peek/binary.rkt` | Existing heuristic treats NUL as binary and offers a port renderer. Detect BOM/encoding before applying it to assembly candidates. |
| `peek-lib/peek/archive.rkt` | ZIP/TAR/TGZ support is separate and buffered. An `ar` archive named `.a` is not thereby supported as an archive tree. |
| `peek-lib/peek/c.rkt`, `wat.rkt` | Useful renderer/API references, but not a ready-made raw-byte/fragment/checkpoint solution. |
| `lexers/.../private/stream.rkt` | Defines common categories; despite its name, it is not a reusable bounded source reader. |
| `lexers/.../c.rkt`, `token.rkt` | Establish projected/derived APIs and parser-tools position compatibility. Assembly must expose named category and provenance accessors. |
| `peek-lib/peek/test/lexers-c-roundtrip.rkt` | Shows the 120-second custodian timeout convention. Assembly additionally needs byte-level tests; stripping ANSI alone is insufficient. |
| `.github/workflows/build-manual.yml` | Checks out `lexers` separately and builds docs. Coordinate dependency availability; add test CI separately from deployment. |

`lexers/asm` now provides the generic, byte-preserving derived-token stream and
the bounded inspection record used by `peek`. The `peek` integration does not
add a second tokenizer: `peek-lib/peek/asm.rkt` maps only named lexer categories
and tags to safe terminal display. The generic profile is the only selectable
dialect; recognized-but-unavailable profiles remain errors rather than aliases
for its grammar.

## 4. Contracts to settle in M0

### Classification and profiles

Use named immutable records for a selection request, profile capabilities,
resolved classification, evidence, diagnostics, and region state. Keep a
distinct origin on each resolved dimension: explicit override, preset,
enabled configuration, content, filename, default, or unknown.

The profile registry distinguishes **implemented**, **recognized only**, and
**unavailable** profiles. Only implemented selections appear in
`--list-file-types`. Recognized but unavailable languages remain conservative
source with an inspectable reason, never an alias for the nearest grammar.

Do not overload the existing `#:profile 'coloring` option with assembler
identity. Coloring/compiler policy and an assembler compatibility profile are
separate concepts. Proposed selection dimensions include `#:architecture`,
`#:cpu`, `#:mode`, `#:dialect`, `#:syntax`, `#:preprocessor`, and `#:encoding`.
Finalize exact names against the shared config conventions before publishing.

Proposed public API includes `make-asm-lexer`, `make-asm-derived-lexer`, small
string helpers, and derived-token accessors for category, text, tags, start/end
positions, byte span, raw bytes, continuation identity, and effective state.
Inspection/detection can live in `lexers/asm/detect` if a separate module keeps
the ordinary lexer dependency small. These are planned APIs, not existing ones.

### Bytes, positions, and fragment ownership

Adopt a reusable byte-source helper in `lexers`, initially used by assembly.
Do not migrate every other lexer as a prerequisite. Keep existing projected
token and parser-tools position meanings unchanged.

Use zero-based, half-open byte spans. Document character offsets, Racket
positions, and unknown positions separately. For string convenience APIs,
define provenance relative to the string's UTF-8 encoding; do not pretend that
an already-decoded string retains the original file encoding.

Prefer immutable, bounded raw-byte values owned by returned fragments for the
first implementation. This gives retained tokens stable bytes while allowing
the scanner to release consumed buffers. A caller that intentionally collects
all tokens may consume proportional memory; the streaming lexer and renderer
must not retain them internally.

Start with an 8–16 KiB fragment cap. Continuations must preserve identity,
source adjacency, and lexical state. Coalescing is a testing/consumer choice,
not an operation the live renderer performs on arbitrarily large tokens.
Projected and derived streams must cover identical bytes under the coloring,
trivia-preserving policy; policies that deliberately drop trivia are not
lossless exports.

Projected token values retain their documented text-oriented convention.
For invalid or non-UTF-8 input, raw reconstruction uses derived fragment bytes
and the associated source mapping, not concatenation of decoded token values.
Specify how projection retains that mapping without changing the meaning of
existing parser-tools position fields.

### Encoding and display

First delivery: UTF-8 including BOM/invalid-byte recovery, plus BOM-selected
UTF-16LE/BE with an incremental decoder and source mapping. Explicit encoding
selection must validate its supported names. Leave guessed legacy encodings
unknown until a specific decoder and fixtures are added. Emitted PETSCII,
screen-code, or character-map directives do not change source decoding.

Recommended display policy: retain printable text, LF, and tabs; render
terminal-active controls, lone CR, and undecodable bytes visibly. Render CRLF
as one terminal line break while preserving both bytes in provenance. Document
the exact escape spelling and width before snapshot tests. Sanitizing happens
before adding renderer-generated ANSI, including when color is disabled.

Token JSONL includes an unambiguous raw-byte encoding, such as base64, so its
fragments can reconstruct the exact input. Do not add a terminal-unsafe raw
display switch for the first milestone. An independent raw export CLI can be
considered later; byte access through the lexer is part of the initial contract.

### Configuration and compatibility

Recommended `peek` integration: one immutable `assembly-options` value supplied
through an optional `#:assembly` keyword on preview entry points. Preserve the
existing positional arguments and `preview-options` constructor. Pass this
record through diff/follow helpers explicitly. Avoid ambient mutable parameters
that could mix settings between simultaneous previews.

Resolution order: explicit dimension overrides, named preset, explicitly enabled
declarative configuration, content evidence, filename hints. Preset defaults
may be overridden when the resulting tuple is supported. Conflicts with a
preset's grammar constraints are usage errors.

Declare Asm-One's baseline version/settings before implementing its preset.
Use the original manual's documented behavior as the initial research target;
record the actual chosen case, column-one-label, and field-comment defaults.
Do not invent settings or claim later-version compatibility without fixtures.

## 5. Detailed milestones

### M0 — Freeze contracts and create the smallest test corpus

Work:

- Check the current revisions and both repositories' `AGENTS.md` files.
- Specify the records, span conventions, fragment ownership, resource caps,
  terminal policy, selection precedence, and JSON schema version.
- Prototype three difficult boundaries: CRLF/UTF decoding across chunks,
  a token larger than the fragment cap, and a short open pipe with no newline.
- Define a needs-input state distinct from EOF. Appended batches must not
  finalize unterminated constructs merely because the current batch ends.
- Resolve the short-pipe prototype before promising first-output latency:
  a bounded probe must not immediately hand off to a lexer that blocks until
  newline or token completion. If provisional neutral display fragments are
  necessary, specify their relationship to deterministic logical tokens and
  later diagnostics; do not silently make token roles depend on arrival timing.
- Create original fixtures for generic ambiguous source, comments/strings with
  misleading CPU names, a UTF-16 source, invalid bytes, binary data named `.s`,
  Pascal versus assembly `.inc`, a huge token, and a stalled producer.
- Establish the provenance manifest and a minimal evidence-rule format.

Exit: the contract is documented and the boundary prototypes demonstrate that
the proposed API can satisfy byte fidelity, finite memory, and startup behavior.

### M1 — Implement the shared assembly stream in `lexers`

Work:

- Add the reusable incremental byte-source/decoder and source-span helpers.
- Add `lexers/asm`, projected-token adaptation, derived accessors, common
  categories, diagnostics, checkpoints, and a small profile registry.
- Implement a conservative generic profile. Preserve disputed comment/string
  syntax neutrally; do not invent a universal semicolon or hash comment rule.
- Implement fragment emission and bounded lookahead for long identifiers,
  strings, comments, whitespace, and data lines. Release consumed buffers.
- Make checkpoint/restart preserve decoder tails, statement position, partial
  tokens, lexical modes, and bounded branch/macro state.
- Add public module tests and `lexers-doc/lexers.scrbl` documentation together.

Exit: projected/derived coloring streams partition arbitrary byte fixtures;
split-point tests, restart tests, malformed recovery, and large-token tests
pass. No whole-file or unbounded-token buffer is required by the generic path.

### M2 — Prepare bounded input and route representations

Work:

- Add one generic input-preparation helper in `peek`: original filename,
  bounded sample, stopping reason, representation facts, and replay port.
- Initially cap sampling at 32 KiB or 256 physical lines, with an approximate
  20 ms availability budget after the first data is available. Treat these as
  tunable settings, not measured guarantees. Bound candidate work as well.
- Count physical lines incrementally; retain enough decoder/newline state to
  handle split CRLF and UTF-16 correctly. Avoid a blocking whole-line reader.
- Replay every sampled/read-ahead byte exactly once. If a chunk crosses a
  sampling limit, retain its unused suffix for replay without scoring it.
- Check BOM/encoding, then supported binary/archive structure, then text/source
  evidence. Record insufficient bytes as incomplete evidence, not a match.
- For automatic assembly candidates, route recognized binary artifacts before
  source lexing. Preserve explicit `--type binary` and `--type archive` behavior.
- Keep forced dialect choices when source evidence disagrees. For a positively
  recognized binary representation supplied with a source override, record the
  requested profile and an artifact conflict, then use safe binary inspection;
  do not reinterpret binary bytes as assembly. Document this exception clearly.
- Handle ordinary `ar` archives and objects conservatively as binary unless an
  actual reader exists. A short Hunk-looking value or C64 load address is not
  sufficient format validation. Exact Hunk/object inspection can follow later.
- Define assembly candidate admission: `.asm`, `.s`, `.S`, `.sx`, and `.nasm`
  are hints; `.inc`, `.i`, `.a`, extensionless files, and stdin require content
  arbitration. Do not move known unrelated file types through every ASM probe.
- Stage filename/content dispatch behind tested capabilities. In the forced
  generic milestone, do not silently activate uncalibrated exact detection.
- When probing abstains on text, continue through a safe streaming fallback;
  do not send the replay port back through the existing whole-input
  `port->bytes` fallback. Preserve binary/encoding uncertainty in inspection.

Exit: no bytes disappear or repeat, UTF-16 is not rejected solely for NULs,
binary negatives avoid source highlighting, and a short stalled pipe stops
probing within the documented budget after data is available. No promise is
made to emit source before the producer supplies any bytes.

### M3 — Deliver generic assembly preview and inspection in `peek`

Work:

- Add `peek-lib/peek/asm.rkt` with string and port renderers using derived tokens
  and named accessors. Use the common palette, with assembly role decisions
  remaining in the assembly module. Unknown/uncertain text stays neutral;
  diagnostic severity is distinct from an unknown category.
- The assembly palette uses only lexer-supplied roles: instructions and
  directives use the keyword color; registers use the builtin color; labels
  and symbols use the identifier color; literals use the literal color;
  punctuation is neutral; comments use the subdued comment color; and malformed
  encoding remains distinct. Do not infer a mnemonic, register, or listing
  annotation from its spelling in `peek`. The generic lexer may identify an
  indented `asm-layout-statement-head`, which uses the keyword color solely to
  preserve the conventional opcode column; it does not claim instruction or
  directive semantics. Other generic symbols use the bright identifier color.
  An explicit or qualified profile enables the richer instruction/register
  distinction.
- Add the assembly configuration record and optional keywords described above.
- Wire string, port, file, and CLI paths. Open byte-authoritative file paths in
  binary mode. String/file convenience functions may collect their result;
  the normal CLI port path must stream.
- Add forced generic selection, validated option combinations, and the
  inspection modes in section 6. `--type asm` means the assembly family; before
  calibrated profiles exist its resolution is conservative and explained. An
  explicit `--dialect` implies `--type asm`, so it remains a forced selection
  rather than entering automatic fallback.
- Route assembly no-color rendering through the same sanitizer and state
  machine. Test stdout/stderr separation, pager forwarding, and prompt flushes.
- Add state-preserving assembly follow support using feed/checkpoint state.
  Keep the selected profile across appends; reset appropriately on truncation
  or replacement. Finite batch completion is not lexer EOF. If this is deferred
  from the first release, reject assembly `--follow` explicitly and document it
  until the follow acceptance tests pass.
- For diff, retain revision-specific selection/state where available. A deleted
  fragment cannot inherit current-revision CPU/syntax state. Render contextless
  snippets conservatively and expose that limitation, or obtain state by
  lexing the corresponding complete revision. Do not guess from hunk text.
- Preserve line numbering/range wrappers. Test grep compatibility separately;
  disclose its existing whole-line buffer rather than claiming every option
  combination has bounded memory.
- Add assembly docs, test instructions, and a short README example. Add a
  shared architectural note/link in `DESIGN.md` when the implementation lands.

Exit: the first-release checklist in section 9 passes using the shared lexer.
This is the first useful delivery; exact dialect detection is not required.

### M4 — Add ca65, ACME, and native Motorola

Implement and test one profile at a time, exposing its explicit selection only
when the relevant grammar and documentation are available.

| Profile | Required coverage |
| --- | --- |
| ca65 | CPU declarations, directives, scoped and cheap-local names, anonymous labels/references, literals, macros, and lexical changes from supported `.feature` settings. |
| ACME | Bang directives, local zones, source/output directives, macro calls, PC expressions, comments, and literals. Output directives record intent only. |
| Native Motorola baseline | Mnemonic suffixes, register lists/addressing, labels/equates, data/section directives, and a deliberately conservative compatible-family result. |
| Asm-One / Devpac presets | Explicitly documented defaults and tested field/label/comment/case/macro differences. Share implementation only where the grammar actually agrees. |

Keep 6502-family evidence independent of exact dialect and 6502 versus 6510.
Keep native m68k compatible sets intact; do not identify a historical tool from
common `move.l`/`dc.b` source. Include native uppercase `.S` as a counterexample
to unconditional CPP selection.

Exit per profile: focused grammar tests, valid/malformed byte round trips,
chunk equivalence, at least an initial audited real-source sample, explicit CLI
selection, documented defaults/limits, and no false certainty in shared subsets.

### M5 — Add Kick, 64tass, and native compatibility refinements

- Give Kick its own script/assembly composition, brace and conditional states,
  imports, macro/function constructs, and anonymous label rules. In particular,
  do not treat all semicolons as line comments.
- Give 64tass its own directive, expression, namespace, literal, and encoding
  directive rules. Preserve the distinction between source decoding and
  emitted character encodings.
- Add only fixture-supported Asm-Pro/PhxAss/vasm compatibility switches; record
  capabilities rather than claiming complete historical emulation.
- Exercise modes/features inside macro bodies and alternative branches. Cap
  state growth and fall back without discarding source.

Exit: M4's profile gates plus nested scripting/macro cases and bounded-state
stress tests. Do not merely add directive lists to a 6502 tokenizer.

### M6 — Add GNU targets and NASM

| Module/profile | Required coverage |
| --- | --- |
| Shared GNU infrastructure | Directive/macro states, numeric local labels, expressions, and target-selected comment/punctuation rules. |
| GNU m68k | MIT/Sun and supported Motorola syntax, target comments, registers/addressing, and ambiguous native/GNU subsets. |
| GNU x86 | Intel/AT&T syntax switches, register-prefix policy, 16/32/64 modes, and GNU macros. `.intel_syntax` must not select NASM. |
| GNU ARM | Unified/divided syntax and ARM/Thumb state as separate fields, target comments, directives, and register aliases. |
| GNU AArch64 | Its own instruction/register/comment rules and relocation forms; conditional Apple/ELF source intent. |
| NASM | `%macro`/`%endmacro`, `%1`, `%%local`, token concatenation, preprocessing, `BITS`, and supported data forms. Distinguish language compatibility from NASM/Yasm executable identity. |

Add a CPP overlay only at established preprocessing boundaries. Reuse/extract
appropriate shared scanner code in `lexers`; do not tokenize the whole source
as C. Keep branch alternatives separate and never apply both branches' state
changes sequentially. Includes remain unvisited and unknown macros remain
valid candidates.

Exit: per-profile gates plus in-file switching, split directives, inactive or
unknown branches, macro-contained switches, and CPP composition tests. CPU
table completeness is not a release blocker; unknown future mnemonics survive.

### M7 — Enable automatic selection profile by profile

`peek` status: implemented. Assembly suffixes enter one bounded probe before
ordinary output. `.inc`, `.i`, `.a`, extensionless input, and stdin require
strong source evidence; unresolved `.inc` input retains the Pascal path. The
probe result freezes before any rendered source fragment is emitted. `peek`
uses a lexer-approved candidate profile when `automatic-enabled?` is true and
otherwise renders plausible assembly as generic. Detection JSON and stderr
explanations expose candidates, evidence, conflicts, scores, calibration state,
and the effective fallback. `--detection-mode fixed-prefix` makes a script wait
for EOF or the bounded probe cap; interactive preview retains the short
availability budget. The remaining lexers-owned qualification work is to admit
held-out calibration records profile by profile.

- Use the shared family scanners in bounded probe mode; do not create a
  regex-only parallel grammar. Keep unknown and plausible non-assembly rivals.
- Collect contextual evidence with rule IDs, byte spans, independent feature
  classes, affected dimensions, conflicts, and region/conditional context.
- Score architecture and dialect independently, then consider compatible
  tuples. A profile cannot win simply by swallowing rival evidence as comments.
- Start with the source design's heuristic weights: declarations +60;
  distinctive construction families +30 capped at +60; instruction/register/
  addressing classes +20 capped at +80; conventions +10; enabled metadata +10;
  filename at most +5; distinct strong unconditional conflicts −50. Do not
  double-count one observation or penalize an unknown mnemonic.
- Initial bands: high at score ≥80 and margin ≥20, with two independent content
  classes and no unresolved strong conflict; probable at ≥60 and margin ≥15;
  otherwise compatible-set/ambiguous/conflicting/unknown. Scores are not
  probabilities. Tune using development data only.
- Preserve dimensions supported by evidence even if another dimension is
  unknown. Close compatible native profiles remain a set, not a tie-break win.
- Enable automatic behavior only after section 8's held-out evaluation.
  Insufficient evaluation data leaves a profile available by explicit selection.
- Resolve the `.inc` collision explicitly: strong assembly evidence can select
  assembly, strong Pascal evidence retains Pascal, and a shared fragment must
  not be advertised as confidently either. Document neutral fallback for
  unresolved includes rather than silently treating all `.inc` as ASM.
- Add fixed-prefix detection for reproducible scripts. Keep low-latency
  detection as the interactive default and disclose schedule-dependent sample
  lengths. Full-file detection is a separate opt-in for seekable files.

Exit: measured detection report, tested abstention, and default enablement only
for qualified profiles. Later evidence does not trigger output reclassification.

### M8 — Explicitly separate subsequent expansions

Add MASM, FASM, armasm, IAR, DASM, TMPx textual syntax, and further legacy
profiles according to corpus-backed demand. MASM delimiter-defined `COMMENT`,
FASM macro grammar, and Arm/IAR dialect differences need their own states.

Listings/disassemblies require wrapper columns and source maps. Tokenized TMP
requires a decoder. Disk images require container handling. Inline assembly
requires host-language boundaries and mappings. Hunk objects, load files, and
libraries require distinct validated format handling. None is a new alias for
ordinary source, and none is needed to complete M3.

Keep unsupported Z80/RISC-V and Go/Plan 9-style source in the negative corpus.
Add an optional versioned ISA validation layer only if requested; lexical
preview must continue to accept unknown instructions conservatively.

## 6. Proposed CLI contract

Preserve `--list-file-types`; the source design's `--list-types` spelling is not
needed. Add names only as their explicit profile support ships.

```sh
# First usable milestone
peek --type asm --dialect generic --no-pager uncertain.inc
peek --type asm --dialect generic --color never uncertain.inc
peek --detect-only --json uncertain.inc
peek --explain-type --type asm --dialect generic uncertain.inc
peek --type asm --dump-tokens=jsonl uncertain.inc

# Explicit profile selections
peek --type asm --dialect ca65 startup.s
peek --type asm --dialect acme program.a
peek --type asm --dialect asmone game.s
peek --type asm --dialect devpac game.s
peek --type asm --dialect kick program.asm
peek --type asm --dialect 64tass program.asm
peek --type asm --dialect gas --arch x86 routine.S
peek --type asm --dialect gas --arch arm startup.S
peek --type asm --dialect gas --arch aarch64 routine.s
peek --type asm --dialect nasm routine.asm

# Proposed reproducible detection control, delivered with M7
peek --type asm --detection-mode fixed-prefix --detect-only --json routine.s
```

Implement selectors only when they have a tested meaning. Include `--dialect`,
`--arch`, `--cpu`, `--mode`, `--syntax`, `--preprocessor`, and `--encoding` as
needed by shipped profiles. `gas` without an established target must not assume
one target's comment rules. A complete forced profile can skip dialect scoring
while retaining bounded representation/encoding checks.

Inspection records include schema version, requested/effective selection,
origin per dimension, effective defaults, lexer/profile version, supported
alternatives, scores/margins, bounded evidence/diagnostics with spans, encoding,
artifact routing, sample bytes/lines/stopping reason, and fallback reason.
Record truncation of evidence or diagnostics explicitly. Do not accumulate a
whole-file list merely to print it at EOF.

`--detect-only --json` writes one JSON result; `--dump-tokens=jsonl` streams token
records. Both bypass ANSI, pager, grep, line numbers, and rendered line ranges;
reject incompatible presentation options clearly. `--explain-type` writes
explanation to stderr and leaves the preview on stdout. Malformed source and
ambiguity normally succeed; I/O errors and invalid options fail. Optional strict
detection is later functionality, with documented nonzero ambiguity behavior.

## 7. Planned file changes and ownership

Paths below are relative to the named repository. New paths are proposals to
confirm against conventions at implementation time.

| Repository / path | Responsibility |
| --- | --- |
| `lexers`: `lexers-lib/lexers/asm.rkt` | Public projected/derived lexer constructors, accessors, small convenience helpers. |
| `lexers`: `lexers-lib/lexers/asm/detect.rkt` | Reusable evidence, selection, and inspection API, if split from the main module. |
| `lexers`: `lexers-lib/lexers/private/source.rkt` | Incremental bytes, decoding, position mapping, bounded storage; assembly is its first client. |
| `lexers`: `lexers-lib/lexers/private/asm/` | Named records, registry, generic scanner, family modules, CPU data, projection, detection, checkpoints. Split further only when useful. |
| `lexers`: `lexers-lib/lexers/asm.rkt` test submodule and `test/asm/` | Contract/unit tests and persistent lexer fixtures/corpus metadata. |
| `lexers`: `tools/build-asm-corpus.rkt`, `tools/check-asm-corpus.rkt` | Reuse `tools/private/corpus-builder.rkt`; optional external corpora skip clearly when unavailable. |
| `lexers`: `DESIGN.md`, `Assembly.md`, `lexers-doc/lexers.scrbl` | Shared byte-layer decisions, assembly semantics, public API. |
| `peek`: `peek-lib/peek/asm.rkt` | Thin token-to-terminal renderer. |
| `peek`: `peek-lib/peek/private/assembly-options.rkt` | Immutable assembly request/options, if a separate module is useful. |
| `peek`: `peek-lib/peek/private/input-probe.rkt` | Generic bounded sampling/replay and representation preparation; no assembler grammar. |
| `peek`: `peek-lib/peek/preview.rkt`, `main.rkt` | Routing, CLI, inspection, options propagation, follow/diff integration. |
| `peek`: `peek-lib/peek/common-style.rkt` | Reusable palette/safe-display helpers only when genuinely shared. |
| `peek`: `peek-lib/peek/binary.rkt`, `archive.rkt` | Small shared signature/representation changes if required; avoid an unrelated format-parser rewrite. |
| `peek`: `peek-lib/peek/test/asm-preview.rkt`, `asm-detection.rkt`, `asm-streaming.rkt`, `asm-cli.rkt`, `lexers-asm-roundtrip.rkt` | Focused RackUnit suites instead of putting all new tests into `unit.rkt`. |
| `peek`: `peek-lib/peek/test/fixtures/asm/` | Small reviewed preview fixtures, expected rendering, provenance and licenses. |
| `peek`: `peek-lib/peek/test/unit.rkt` | Minimal cross-language regression cases. |
| `peek`: `peek-doc/peek.scrbl`, `README.md`, `DESIGN.md`, `Assembly.md` | User documentation and implementation/design record. |
| `peek`: `peek-lib/info.rkt`, a test CI workflow | Required lexer version when available; fast tests and separate corpus/performance jobs. |

Keep one canonical large corpus in `lexers` or an explicitly configured external
snapshot. `peek` owns a small integration subset with parent hashes; do not
duplicate an entire third-party corpus. Generated large inputs are temporary
outputs from persistent generators, not committed 100 MiB fixtures.

## 8. Test and corpus plan

### Required test matrix

| Area | Cases and assertions |
| --- | --- |
| Byte fidelity | Concatenate raw fragments to reproduce exact bytes; adjacent ordered spans start at zero and end at EOF; projected/derived coloring coverage agrees. |
| Positions/decoding | UTF-8, BOM, UTF-16LE/BE, split code units, invalid sequences, LF/CRLF/lone CR, tabs, non-ASCII identifiers, no final newline. Assert byte and Racket coordinates independently. |
| Chunking | Every split point for short constructs; randomized/tiny chunks for large cases; normalized logical token equality and checkpoint restart equivalence. |
| Replay | Marker sequences across each probe boundary appear exactly once in output and provenance; sample/read-ahead limits are reported correctly. |
| Recovery | Unterminated strings/comments/macros, invalid escapes, capped nesting/alternatives, unknown instructions/macros, unsupported encoding. Progress and preserved bytes are mandatory. |
| Context | Mnemonics/directives inside strings/comments do not become evidence; macro-contained switches do not execute; conditional branches join conservatively. |
| Ambiguity | Shared 6502 code, common native m68k, constant-only includes, GNU Intel versus NASM, overlapping `.segment`/`.var`, native `.S`, NASM/MASM shared data forms. |
| Negative inputs | C, Pascal, Rust, shell, BASIC, JSON, prose/manuals, unsupported CPUs, archives, objects, disk images, text hex formats, tokenized source with misleading suffixes. |
| CLI | Explicit valid/invalid tuples, aliases, stdin/file equivalence, list output, JSON/JSONL schemas, stderr separation, exit status, color modes and pager behavior. |
| Display | ESC/CSI/OSC, control bytes, CR, invalid encoding, wide text/tabs. Compare display against escaped expectations; raw fidelity is a different assertion. |
| Existing modes | Line numbers/ranges, grep, diff old/new state, follow append/truncate/replace, default color, `--no-pager`, Pascal `.inc`, Racket suffixes, WAT streaming. |
| Runtime | Large line/token, slow producer, open pipe stalled after short prefix, cancellation, early reader close, pager exit, backpressure, consumed-buffer release. |

For safe plain-text fixtures only, retain the familiar strip-ANSI rendering
round-trip test. For controls/encoding cases, assert escaped display and raw
reconstruction separately. No test may pass simply because output was silently
truncated, skipped, or normalized.

Use custodians or subprocess isolation for hard corpus deadlines. The timer
covers reading, lexing, rendering, and comparison, not just a token callback.
Report fixture path, profile, mode, and timeout. Shut down timed-out workers and
their owned resources. Core authored tests always run; only optional downloaded
corpora may skip with an explicit message.

### Acquisition and ground truth

Use the supplied design's candidate projects: cc65, ACME examples, c64lib,
64tass, paired `keirf/amiga-stuff` inflate sources, native uppercase `.S` from
`cdyk/amigacoding`, dav1d NASM/ARM64, .NET MASM/GNU Intel, CMSIS Arm/GNU startup,
and selected LLVM MC tests. These are acquisition candidates, not preapproved
redistributable fixtures. Do not download or run them as part of this plan.

Before admission, pin repository/commit/path and retrieval date; hash untouched
bytes; review relevant notices/terms; retain attribution/license texts; record
transformations and generated inputs/seed. Build commands and tool options are
metadata unless a separate controlled oracle test deliberately executes them.
Write original syntax fixtures when a historical example lacks usable rights.

Manifest fields: fixture ID, original filename/path/revision, SHA-256, license
expression/path and attribution, lineage, transformations, source encoding and
newlines, architecture/CPU/mode/syntax/dialect, processing layers, source output
intent, build provenance, expected acceptable content-only selections,
forced-profile expectations, and expected diagnostics.

Keep two truths: what the original build used, and what the source alone can
identify. Preserve that distinction in detector assertions. Split tuning and
evaluation by project/lineage, keeping forks, derivatives, and generated variants
together. Aim for several independent lineages, initially at least three per
P1 profile, before describing the evaluation as representative.

### Detection and performance gates

Report architecture and dialect precision separately, accepted sample counts,
coverage/abstention, false positives, confusion matrices, confidence intervals,
and breakdowns by encoding, size, macros, and representation. The proposed
high-confidence target is at least 99% held-out precision; a tiny all-correct
fixture set does not establish that claim. Curated ambiguity and binary-negative
cases allow no high-confidence false exact-dialect selections.

Metamorphic tests rename extensions, prepend comments, move apparent cues into
strings, repeat weak evidence, and truncate before strong cues. Case/whitespace
changes are valid transformations only where the selected grammar permits them.

Measure cold/warm first visible output, bytes consumed before it, throughput,
and peak additional memory on a named machine/Racket version. Compare against
an appropriate existing plain streaming path; unknown-input fallback currently
buffers, so it is not by itself a useful startup baseline. The design's 20–50 ms
additional ready-input probing objective is a tuning target, not a guarantee.

Generate 1, 10, and 100 MiB workloads and giant single-token/line variants.
Routine CI uses deterministic correctness/buffering assertions and modest
timeouts; larger timing/memory runs are an explicit performance job. State the
limits of `--grep`, buffered diff, archive preview, and string-returning APIs
separately from the ordinary assembly port stream.

## 9. First-release acceptance checklist

- [x] `lexers/asm` exists with documented projected/derived accessors and a
  conservative generic profile.
- [x] Raw fragments reconstruct bytes exactly; positions, decoder state,
  continuations, and checkpoints pass their contract tests.
- [x] The normal assembly port path buffers neither the file nor an unbounded
  token/line, and the stalled-producer prototype passes end to end.
- [x] `peek --type asm --dialect generic` works for files and stdin, with color
  on or off, using the shared lexer.
- [x] Representation checks distinguish supported text encodings from binary
  evidence, and replay every prefix byte exactly once.
- [x] Detection JSON and token JSONL are valid, stable, ANSI-free, and bypass the
  pager; normal explanations do not contaminate stdout.
- [x] Unsupported/ambiguous/malformed input is preserved and does not acquire
  unsupported CPU/dialect certainty.
- [x] Follow is explicitly unavailable for assembly until its stateful lexer
  integration is implemented; contextless diff fragments are rendered
  conservatively.
- [x] Existing defaults, list spelling, pager behavior, Pascal includes, Racket
  suffixes, and WAT streaming have regression coverage.
- [ ] Tests use hard corpus deadlines, provenance is present, and both manuals
  describe the actually shipped APIs and behavior.
- [ ] The needed `lexers` release/revision is available before `peek` depends on
  it. An older package cannot fail with an unexplained missing-module error.

## 10. Verification commands and delivery sequence

These commands are for the implementation, after the proposed files exist.
They were not run by this documentation-only planning task.

From `/Users/soegaard/Dropbox/GitHub/lexers`:

```sh
raco test lexers-lib/lexers/asm.rkt lexers-lib/lexers/asm/detect.rkt
raco test test/asm
racket tools/check-asm-corpus.rkt
raco scribble +m --htmls --dest html/ lexers-doc/lexers.scrbl
```

From `/Users/soegaard/Dropbox/GitHub/peek`:

```sh
raco test peek-lib/peek/asm.rkt peek-lib/peek/test/asm-preview.rkt peek-lib/peek/test/asm-streaming.rkt
raco test peek-lib/peek/test/asm-detection.rkt peek-lib/peek/test/asm-cli.rkt peek-lib/peek/test/lexers-asm-roundtrip.rkt
raco test peek-lib/peek/main.rkt peek-lib/peek/preview.rkt peek-lib/peek/test/unit.rkt
raco scribble +m --htmls --dest html/ peek-doc/peek.scrbl
```

Adjust paths only if the agreed module layout changes. Use the existing package
test process for impacted shared lexer helpers, especially if any C scanner
code is extracted for CPP. In Scribble prose, use `@"@"` for a literal `@`.

Prefer reviewable deliveries: (1) contracts/source foundation and lexer tests,
(2) generic lexer plus public documentation, (3) bounded `peek` preparation and
renderer, (4) CLI/inspection and integration tests, then separate profile changes
and calibrated detection enablement. Source foundation and generic API may be
one upstream change if that makes the invariant easier to review.

For each delivery record the exact dependency revision, implemented profile
settings, tests run, measurements actually obtained, and remaining limits.
Do not describe provisional scoring thresholds or unmeasured latency targets as
validated behavior. Update this document as decisions settle; move shared
decisions into `DESIGN.md` without turning `AGENTS.md` into an assembly manual.
