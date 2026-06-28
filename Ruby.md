# Ruby Preview Notes

`peek` treats Ruby as a regular text-language previewer, not as a shell or
template special case.

Current behavior:

- `.rb`, `.rake`, and `.gemspec` files use the Ruby previewer
- common extensionless Ruby file names such as `Gemfile`, `Rakefile`,
  `Guardfile`, and `Appraisals` also use the Ruby previewer
- rendering is source-preserving and color-only
- malformed input uses best-effort previewing through the `lexers/ruby`
  coloring profile

The first version intentionally keeps the Ruby previewer simple. It colors the
token stream from `lexers/ruby` directly instead of adding Ruby-specific layout
rewriting or structural formatting.
