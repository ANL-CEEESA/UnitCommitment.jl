# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

VERSION := 0.4

docs:
	cd docs; julia --project=. -e 'include("make.jl"); make()'; cd ..
	rsync -avP --delete-after docs/build/ ../docs/$(VERSION)/

test:
	julia --project=test -e 'using UnitCommitmentT; format(); runtests()'
	
.PHONY: docs test
