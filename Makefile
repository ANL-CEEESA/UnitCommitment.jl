# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

JULIA := julia --color=yes --project=@.
MKDOCS := ~/.local/bin/mkdocs
VERSION := 0.2

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	mkdir -p build
	mkdir -p benchmark/results/test
	cd benchmark; $(JULIA) --trace-compile=../build/precompile.jl run.jl test/case14.1.sol.json
	$(JULIA) src/sysimage.jl

clean:
	rm -rf build/*

docs:
	$(MKDOCS) build -d ../docs/$(VERSION)/
	rm ../docs/$(VERSION)/*.ipynb
	
install-deps-docs:
	pip install --user mkdocs mkdocs-cinder python-markdown-math

test: build/sysimage.so
	@echo Running tests...
	$(JULIA) --sysimage build/sysimage.so -e 'using Pkg; Pkg.test("UnitCommitment")' | tee build/test.log

.PHONY: docs test
