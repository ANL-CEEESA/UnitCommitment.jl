# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

SHELL := /bin/bash
JULIA := julia --project=. --sysimage ../build/sysimage.so
TIMESTAMP := $(shell date "+%Y-%m-%d %H:%M")
SRC_FILES := $(wildcard ../src/*.jl)
DEST := .
FORMULATION := tight
results_dir := results_$(FORMULATION)

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

INSTANCES_INFORMS1 := \
  matpower/case1888rte/2017-01-01 \
  matpower/case1888rte/2017-01-02 \
  matpower/case1888rte/2017-01-03 \
  matpower/case1888rte/2017-01-04 \
  matpower/case1888rte/2017-01-05 \
  matpower/case1888rte/2017-01-06 \
  matpower/case1888rte/2017-01-07 \
  matpower/case1888rte/2017-01-08 \
  matpower/case1888rte/2017-01-09 \
  matpower/case1888rte/2017-01-10 \
  matpower/case1888rte/2017-01-11 \
  matpower/case1888rte/2017-01-12 \
  matpower/case1888rte/2017-01-13 \
  matpower/case1888rte/2017-01-14 \
  matpower/case1888rte/2017-01-15 \
  matpower/case1888rte/2017-01-16 \
  matpower/case1888rte/2017-01-17 \
  matpower/case1888rte/2017-01-18 \
  matpower/case1888rte/2017-01-19 \
  matpower/case1888rte/2017-01-20 \
  matpower/case1888rte/2017-01-21 \
  matpower/case1888rte/2017-01-22 \
  matpower/case1888rte/2017-01-23 \
  matpower/case1888rte/2017-01-24 \
  matpower/case1888rte/2017-01-25 \
  matpower/case1888rte/2017-01-26 \
  matpower/case1888rte/2017-01-27 \
  matpower/case1888rte/2017-01-28 \
  matpower/case1888rte/2017-01-29 \
  matpower/case1888rte/2017-01-30 \
  matpower/case1888rte/2017-01-31 \
  matpower/case1888rte/2017-02-01 \
  matpower/case1888rte/2017-02-02 \
  matpower/case1888rte/2017-02-03 \
  matpower/case1888rte/2017-02-04 \
  matpower/case1888rte/2017-02-05 \
  matpower/case1888rte/2017-02-06 \
  matpower/case1888rte/2017-02-07 \
  matpower/case1888rte/2017-02-08 \
  matpower/case1888rte/2017-02-09 \
  matpower/case1888rte/2017-02-10 \
  matpower/case1888rte/2017-02-11 \
  matpower/case1888rte/2017-02-12 \
  matpower/case1888rte/2017-02-13 \
  matpower/case1888rte/2017-02-14 \
  matpower/case1888rte/2017-02-15 \
  matpower/case1888rte/2017-02-16 \
  matpower/case1888rte/2017-02-17 \
  matpower/case1888rte/2017-02-18 \
  matpower/case1888rte/2017-02-19 \
  matpower/case1888rte/2017-02-20 \
  matpower/case1888rte/2017-02-21 \
  matpower/case1888rte/2017-02-22 \
  matpower/case1888rte/2017-02-23 \
  matpower/case1888rte/2017-02-24 \
  matpower/case1888rte/2017-02-25 \
  matpower/case1888rte/2017-02-26 \
  matpower/case1888rte/2017-02-27 \
  matpower/case1888rte/2017-02-28 \
  matpower/case1888rte/2017-03-01

INSTANCES_INFORMS2 := \
  matpower/case3375wp/2017-01-01 \
  matpower/case3375wp/2017-01-02 \
  matpower/case3375wp/2017-01-03 \
  matpower/case3375wp/2017-01-04 \
  matpower/case3375wp/2017-01-05 \
  matpower/case3375wp/2017-01-06 \
  matpower/case3375wp/2017-01-07 \
  matpower/case3375wp/2017-01-08 \
  matpower/case3375wp/2017-01-09 \
  matpower/case3375wp/2017-01-10 \
  matpower/case3375wp/2017-01-11 \
  matpower/case3375wp/2017-01-12 \
  matpower/case3375wp/2017-01-13 \
  matpower/case3375wp/2017-01-14 \
  matpower/case3375wp/2017-01-15 \
  matpower/case3375wp/2017-01-16 \
  matpower/case3375wp/2017-01-17 \
  matpower/case3375wp/2017-01-18 \
  matpower/case3375wp/2017-01-19 \
  matpower/case3375wp/2017-01-20 \
  matpower/case3375wp/2017-01-21 \
  matpower/case3375wp/2017-01-22 \
  matpower/case3375wp/2017-01-23 \
  matpower/case3375wp/2017-01-24 \
  matpower/case3375wp/2017-01-25 \
  matpower/case3375wp/2017-01-26 \
  matpower/case3375wp/2017-01-27 \
  matpower/case3375wp/2017-01-28 \
  matpower/case3375wp/2017-01-29 \
  matpower/case3375wp/2017-01-30 \
  matpower/case3375wp/2017-01-31 \
  matpower/case3375wp/2017-02-01 \
  matpower/case3375wp/2017-02-02 \
  matpower/case3375wp/2017-02-03 \
  matpower/case3375wp/2017-02-04 \
  matpower/case3375wp/2017-02-05 \
  matpower/case3375wp/2017-02-06 \
  matpower/case3375wp/2017-02-07 \
  matpower/case3375wp/2017-02-08 \
  matpower/case3375wp/2017-02-09 \
  matpower/case3375wp/2017-02-10 \
  matpower/case3375wp/2017-02-11 \
  matpower/case3375wp/2017-02-12 \
  matpower/case3375wp/2017-02-13 \
  matpower/case3375wp/2017-02-14 \
  matpower/case3375wp/2017-02-15 \
  matpower/case3375wp/2017-02-16 \
  matpower/case3375wp/2017-02-17 \
  matpower/case3375wp/2017-02-18 \
  matpower/case3375wp/2017-02-19 \
  matpower/case3375wp/2017-02-20 \
  matpower/case3375wp/2017-02-21 \
  matpower/case3375wp/2017-02-22 \
  matpower/case3375wp/2017-02-23 \
  matpower/case3375wp/2017-02-24 \
  matpower/case3375wp/2017-02-25 \
  matpower/case3375wp/2017-02-26 \
  matpower/case3375wp/2017-02-27 \
  matpower/case3375wp/2017-02-28 \
  matpower/case3375wp/2017-03-01

INSTANCES_INFORMS3 := \
  matpower/case6468rte/2017-01-01 \
  matpower/case6468rte/2017-01-02 \
  matpower/case6468rte/2017-01-03 \
  matpower/case6468rte/2017-01-04 \
  matpower/case6468rte/2017-01-05 \
  matpower/case6468rte/2017-01-06 \
  matpower/case6468rte/2017-01-07 \
  matpower/case6468rte/2017-01-08 \
  matpower/case6468rte/2017-01-09 \
  matpower/case6468rte/2017-01-10 \
  matpower/case6468rte/2017-01-11 \
  matpower/case6468rte/2017-01-12 \
  matpower/case6468rte/2017-01-13 \
  matpower/case6468rte/2017-01-14 \
  matpower/case6468rte/2017-01-15 \
  matpower/case6468rte/2017-01-16 \
  matpower/case6468rte/2017-01-17 \
  matpower/case6468rte/2017-01-18 \
  matpower/case6468rte/2017-01-19 \
  matpower/case6468rte/2017-01-20 \
  matpower/case6468rte/2017-01-21 \
  matpower/case6468rte/2017-01-22 \
  matpower/case6468rte/2017-01-23 \
  matpower/case6468rte/2017-01-24 \
  matpower/case6468rte/2017-01-25 \
  matpower/case6468rte/2017-01-26 \
  matpower/case6468rte/2017-01-27 \
  matpower/case6468rte/2017-01-28 \
  matpower/case6468rte/2017-01-29 \
  matpower/case6468rte/2017-01-30 \
  matpower/case6468rte/2017-01-31 \
  matpower/case6468rte/2017-02-01 \
  matpower/case6468rte/2017-02-02 \
  matpower/case6468rte/2017-02-03 \
  matpower/case6468rte/2017-02-04 \
  matpower/case6468rte/2017-02-05 \
  matpower/case6468rte/2017-02-06 \
  matpower/case6468rte/2017-02-07 \
  matpower/case6468rte/2017-02-08 \
  matpower/case6468rte/2017-02-09 \
  matpower/case6468rte/2017-02-10 \
  matpower/case6468rte/2017-02-11 \
  matpower/case6468rte/2017-02-12 \
  matpower/case6468rte/2017-02-13 \
  matpower/case6468rte/2017-02-14 \
  matpower/case6468rte/2017-02-15 \
  matpower/case6468rte/2017-02-16 \
  matpower/case6468rte/2017-02-17 \
  matpower/case6468rte/2017-02-18 \
  matpower/case6468rte/2017-02-19 \
  matpower/case6468rte/2017-02-20 \
  matpower/case6468rte/2017-02-21 \
  matpower/case6468rte/2017-02-22 \
  matpower/case6468rte/2017-02-23 \
  matpower/case6468rte/2017-02-24 \
  matpower/case6468rte/2017-02-25 \
  matpower/case6468rte/2017-02-26 \
  matpower/case6468rte/2017-02-27 \
  matpower/case6468rte/2017-02-28 \
  matpower/case6468rte/2017-03-01

INSTANCES_TEST := \
	test/case14

#SAMPLES := 1 2 3
SAMPLES := 1
SOLUTIONS_MATPOWER := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_MATPOWER))))
SOLUTIONS_PGLIB := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_PGLIB))))
SOLUTIONS_INFORMS1 := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_INFORMS1))))
SOLUTIONS_INFORMS2 := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_INFORMS2))))
SOLUTIONS_INFORMS3 := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_INFORMS3))))
SOLUTIONS_TEST := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_TEST))))

.PHONY: tables save small large clean-mps matpower pglib informs1 informs2 informs3 test pglib orlib

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

SOLUTIONS_ORLIB := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_ORLIB))))
SOLUTIONS_TEJADA19 := $(foreach s,$(SAMPLES),$(addprefix $(results_dir)/,$(addsuffix .$(s).sol.json,$(INSTANCES_TEJADA19))))

all: matpower pglib orlib tejada19

matpower: $(SOLUTIONS_MATPOWER)

pglib: $(SOLUTIONS_PGLIB)

informs1: $(SOLUTIONS_INFORMS1)
informs2: $(SOLUTIONS_INFORMS2)
informs3: $(SOLUTIONS_INFORMS3)

test: $(SOLUTIONS_TEST)

orlib: $(SOLUTIONS_ORLIB)

tejada19: $(SOLUTIONS_TEJADA19)

clean:
	@rm -rf tables/benchmark* tables/compare* $(results_dir)
    
clean-mps:
	@rm -fv $(results_dir)/*/*.mps.gz results/*/*/*.mps.gz

clean-sol:
	@rm -rf $(results_dir)/*/*.sol.* results/*/*/*.sol.*
        
save:
	mkdir -p "runs/$(TIMESTAMP)"
	rsync -avP $(results_dir) tables "runs/$(TIMESTAMP)/"

results/%.sol.json: run.jl
	@echo "run  $*"
	@mkdir -p $(dir $(DEST)/$(results_dir)/$*)
	@$(JULIA) run.jl $* default $(DEST)/$(results_dir) 2>&1 | cat > $(DEST)/$(results_dir)/$*.log
	@echo "run  $* [done]"

results_tight/%.sol.json: run.jl
	@echo "run  $*"
	@mkdir -p $(dir $(DEST)/$(results_dir)/$*)
	@$(JULIA) run.jl $* tight $(DEST)/$(results_dir) 2>&1 | cat > $(DEST)/$(results_dir)/$*.log
	@echo "run  $* [done]"

results_default/%.sol.json: run.jl
	@echo "run  $*"
	@mkdir -p $(dir $(DEST)/$(results_dir)/$*)
	@$(JULIA) run.jl $* default $(DEST)/$(results_dir) 2>&1 | cat > $(DEST)/$(results_dir)/$*.log
	@echo "run  $* [done]"

results_sparse/%.sol.json: run.jl
	@echo "run  $*"
	@mkdir -p $(dir $(DEST)/$(results_dir)/$*)
	@$(JULIA) run.jl $* sparse $(DEST)/$(results_dir) 2>&1 | cat > $(DEST)/$(results_dir)/$*.log
	@echo "run  $* [done]"

tables:
	@mkdir -p tables
	@python scripts/table.py
	#@python scripts/compare.py tables/reference.csv tables/benchmark.csv
