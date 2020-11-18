# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

JULIA := julia --color=yes --project=@.
MKDOCS := ~/.local/bin/mkdocs
SRC_FILES := $(wildcard src/*.jl) $(wildcard test/*.jl)
VERSION := 0.1

build/sysimage.so: src/sysimage.jl Project.toml Manifest.toml
	mkdir -p build
	$(JULIA) --trace-compile=precompile.jl benchmark/run.jl test/case14.json.gz
	$(JULIA) src/sysimage.jl
	rm precompile.jl

clean:
	rm -rf build/*

docs:
	$(MKDOCS) build -d ../docs/$(VERSION)/
	rm ../docs/$(VERSION)/*.ipynb
	
docs-push:
	rsync -avP docs/ isoron@axavier.org:/www/axavier.org/projects/UnitCommitment.jl/

install-deps-docs:
	pip install --user mkdocs mkdocs-cinder python-markdown-math

test: build/sysimage.so
	@echo Running tests...
	$(JULIA) --sysimage build/sysimage.so -e 'using Pkg; Pkg.test("UnitCommitment")' | tee build/test.log

.PHONY: docs docs-push build test
