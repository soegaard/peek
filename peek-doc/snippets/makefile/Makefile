# Build the preview samples.
APP = peek

docs: assets
	raco scribble +m --html --dest html/ peek-doc/peek.scrbl

assets:
	@printf 'building %s\n' "$(APP)"
