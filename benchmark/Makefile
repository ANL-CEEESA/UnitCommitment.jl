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
	pglib-uc/ca/2015-03-01_reserves_0 \
	pglib-uc/ca/2015-06-01_reserves_0 \
	pglib-uc/ca/Scenario400_reserves_1 \
	pglib-uc/ferc/2015-01-01_lw \
	pglib-uc/ferc/2015-05-01_lw \
	pglib-uc/ferc/2015-07-01_hw \
	pglib-uc/ferc/2015-10-01_lw \
	pglib-uc/ferc/2015-12-01_lw \
	pglib-uc/rts_gmlc/2020-04-03 \
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
	matpower/case1888rte/2017-02-01 \
	matpower/case1951rte/2017-08-01 \
	matpower/case2848rte/2017-02-01 \
	matpower/case2868rte/2017-08-01 \
	matpower/case3375wp/2017-08-01 \
	matpower/case6468rte/2017-08-01 \
	matpower/case6515rte/2017-08-01

INSTANCES_ORLIB := \
	or-lib/20_0_1_w \
	or-lib/20_0_5_w \
	or-lib/50_0_2_w \
	or-lib/75_0_2_w \
	or-lib/100_0_1_w \
	or-lib/100_0_4_w \
	or-lib/100_0_5_w \
	or-lib/200_0_3_w \
	or-lib/200_0_7_w \
	or-lib/200_0_9_w

INSTANCES_TEJADA19 := \
	tejada19/UC_24h_290g \
	tejada19/UC_24h_623g \
	tejada19/UC_24h_959g \
	tejada19/UC_24h_1577g \
	tejada19/UC_24h_1888g \
	tejada19/UC_168h_72g \
	tejada19/UC_168h_86g \
	tejada19/UC_168h_130g \
	tejada19/UC_168h_131g \
	tejada19/UC_168h_199g

SAMPLES := 1 2 3 4 5
SOLUTIONS_MATPOWER := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_MATPOWER))))
SOLUTIONS_PGLIB := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_PGLIB))))
SOLUTIONS_ORLIB := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_ORLIB))))
SOLUTIONS_TEJADA19 := $(foreach s,$(SAMPLES),$(addprefix results/,$(addsuffix .$(s).sol.json,$(INSTANCES_TEJADA19))))

.PHONY: matpower pglib orlib tejada19 clean clean-mps clean-sol save tables

all: matpower pglib orlib tejada19

matpower: $(SOLUTIONS_MATPOWER)

pglib: $(SOLUTIONS_PGLIB)

orlib: $(SOLUTIONS_ORLIB)

tejada19: $(SOLUTIONS_TEJADA19)

clean:
	@rm -rf tables/benchmark* tables/compare* results
    
clean-mps:
	@rm -fv results/*/*.mps.gz results/*/*/*.mps.gz

clean-sol:
	@rm -rf results/*/*.sol.* results/*/*/*.sol.*
        
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
