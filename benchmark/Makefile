# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

SHELL := /bin/bash
JULIA := julia --project=. --sysimage ../build/sysimage.so
TIMESTAMP := $(shell date "+%Y-%m-%d %H:%M")
SRC_FILES := $(wildcard ../src/*.jl)

INSTANCES_PGLIB := \
        pglib-uc/ca/2014-09-01_reserves_0 \
        pglib-uc/ca/2014-09-01_reserves_1 \
        pglib-uc/ca/2014-09-01_reserves_3 \
        pglib-uc/ca/2014-09-01_reserves_5 \
        pglib-uc/ca/2014-12-01_reserves_0 \
        pglib-uc/ca/2014-12-01_reserves_1 \
        pglib-uc/ca/2014-12-01_reserves_3 \
        pglib-uc/ca/2014-12-01_reserves_5 \
        pglib-uc/ca/2015-03-01_reserves_0 \
        pglib-uc/ca/2015-03-01_reserves_1 \
        pglib-uc/ca/2015-03-01_reserves_3 \
        pglib-uc/ca/2015-03-01_reserves_5 \
        pglib-uc/ca/2015-06-01_reserves_0 \
        pglib-uc/ca/2015-06-01_reserves_1 \
        pglib-uc/ca/2015-06-01_reserves_3 \
        pglib-uc/ca/2015-06-01_reserves_5 \
        pglib-uc/ca/Scenario400_reserves_0 \
        pglib-uc/ca/Scenario400_reserves_1 \
        pglib-uc/ca/Scenario400_reserves_3 \
        pglib-uc/ca/Scenario400_reserves_5 \
        pglib-uc/ferc/2015-01-01_hw \
        pglib-uc/ferc/2015-01-01_lw \
        pglib-uc/ferc/2015-02-01_hw \
        pglib-uc/ferc/2015-02-01_lw \
        pglib-uc/ferc/2015-03-01_hw \
        pglib-uc/ferc/2015-03-01_lw \
        pglib-uc/ferc/2015-04-01_hw \
        pglib-uc/ferc/2015-04-01_lw \
        pglib-uc/ferc/2015-05-01_hw \
        pglib-uc/ferc/2015-05-01_lw \
        pglib-uc/ferc/2015-06-01_hw \
        pglib-uc/ferc/2015-06-01_lw \
        pglib-uc/ferc/2015-07-01_hw \
        pglib-uc/ferc/2015-07-01_lw \
        pglib-uc/ferc/2015-08-01_hw \
        pglib-uc/ferc/2015-08-01_lw \
        pglib-uc/ferc/2015-09-01_hw \
        pglib-uc/ferc/2015-09-01_lw \
        pglib-uc/ferc/2015-10-01_hw \
        pglib-uc/ferc/2015-10-01_lw \
        pglib-uc/ferc/2015-11-02_hw \
        pglib-uc/ferc/2015-11-02_lw \
        pglib-uc/ferc/2015-12-01_hw \
        pglib-uc/ferc/2015-12-01_lw \
        pglib-uc/rts_gmlc/2020-01-27 \
        pglib-uc/rts_gmlc/2020-02-09 \
        pglib-uc/rts_gmlc/2020-03-05 \
        pglib-uc/rts_gmlc/2020-04-03 \
        pglib-uc/rts_gmlc/2020-05-05 \
        pglib-uc/rts_gmlc/2020-06-09 \
        pglib-uc/rts_gmlc/2020-07-06 \
        pglib-uc/rts_gmlc/2020-08-12 \
        pglib-uc/rts_gmlc/2020-09-20 \
        pglib-uc/rts_gmlc/2020-10-27 \
        pglib-uc/rts_gmlc/2020-11-25 \
        pglib-uc/rts_gmlc/2020-12-23

INSTANCES_MATPOWER := \
	matpower/case118/2017-02-01 \
	matpower/case118/2017-08-01 \
	matpower/case300/2017-02-01 \
	matpower/case300/2017-08-01 \
	matpower/case1354pegase/2017-02-01 \
	matpower/case1354pegase/2017-08-01 \
	matpower/case1888rte/2017-02-01 \
	matpower/case1888rte/2017-08-01 \
	matpower/case1951rte/2017-02-01 \
	matpower/case1951rte/2017-08-01 \
	matpower/case2848rte/2017-02-01 \
	matpower/case2848rte/2017-08-01 \
	matpower/case2868rte/2017-02-01 \
	matpower/case2868rte/2017-08-01 \
	matpower/case3375wp/2017-02-01 \
	matpower/case3375wp/2017-08-01 \
	matpower/case6468rte/2017-02-01 \
	matpower/case6468rte/2017-08-01 \
	matpower/case6515rte/2017-02-01 \
	matpower/case6515rte/2017-08-01

SAMPLES := 1 2 3
SOLUTIONS_MATPOWER := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_MATPOWER))))
SOLUTIONS_PGLIB := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_PGLIB))))

.PHONY: tables save small large clean-mps matpower pglib

all: matpower pglib

matpower: $(SOLUTIONS_MATPOWER)

pglib: $(SOLUTIONS_PGLIB)

clean:
	@rm -rf tables/benchmark* tables/compare* results
    
clean-mps:
	@rm -fv results/*/*/*.mps.gz

clean-sol:
	@rm -rf results/*/*/*.sol.*
        
save:
	mkdir -p "runs/$(TIMESTAMP)"
	rsync -avP results tables "runs/$(TIMESTAMP)/"

results/%.sol.json: run.jl
	@echo "run  $*"
	@mkdir -p $(dir results/$*)
	@$(JULIA) run.jl $* 2>&1 | cat > results/$*.log
	@echo "run  $* [done]"

tables:
	@mkdir -p tables
	@python scripts/table.py
	#@python scripts/compare.py tables/reference.csv tables/benchmark.csv
