# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

VERSION := 0.3

docs:
	cd docs; julia --project=. make.jl; cd ..
	rsync -avP --delete-after docs/build/ ../docs/$(VERSION)/
	
.PHONY: docs
