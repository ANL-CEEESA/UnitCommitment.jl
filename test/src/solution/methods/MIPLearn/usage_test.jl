# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS

function solution_methods_MIPLearn_usage_test()
    dirname = mktempdir()
    cp(fixture("case14.json.gz"), "$dirname/case14.json.gz")
    train_data = ["$dirname/case14.json.gz"]

    method = UnitCommitment.MIPLearnMethod(optimizer = HiGHS.Optimizer)
    UnitCommitment.collect!(train_data, method)
    UnitCommitment.fit!(train_data, method)
    UnitCommitment.optimize!(train_data[1], method)

    instance = UnitCommitment.read(train_data[1])
    UnitCommitment.optimize!(instance, method)
    return
end
