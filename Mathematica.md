# Mathematica

Standalone Mathematica / Wolfram Language preview in `peek` builds on
`lexers/mathematica`.

The current dispatch layer recognizes:

- `.wl`
- `.wls`

The ambiguous `.m` extension remains reserved for Objective-C in `peek`, even
though `lexers/mathematica` can tokenize Wolfram-like `.m` source. That keeps
the standalone file dispatch predictable until there is a clearer consumer-side
story for disambiguating `.m`.
