# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

VERSION := 0.3

clean:
	rm -rfv build Manifest.toml test/Manifest.toml deps/formatter/build deps/formatter/Manifest.toml

docs:
	cd docs; make clean; make dirhtml
	rsync -avP --delete-after docs/_build/dirhtml/ ../docs/$(VERSION)/
	
format:
	cd deps/formatter; ../../juliaw format.jl

test: test/Manifest.toml
	./juliaw test/runtests.jl

test/Manifest.toml: test/Project.toml
	julia --project=test -e "using Pkg; Pkg.instantiate()"

.PHONY: docs test format install-deps
