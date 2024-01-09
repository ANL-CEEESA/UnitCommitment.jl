# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using .MIPLearn
using Suppressor
using JuMP

function _build_ucjl_model(instance, method)
    if instance isa String
        instance = UnitCommitment.read(instance)
    end
    model = UnitCommitment.build_model(
        instance = instance,
        optimizer = method.optimizer,
        variable_names = true,
    )
    write_to_file(model, "/tmp/model.lp")
    return JumpModel(model)
end

function _set_default_collectors!(method::MIPLearnMethod)
    method.collectors = [BasicCollector()]
    return
end

function _set_default_solver!(method::MIPLearnMethod)
    KNN = MIPLearn.pyimport("sklearn.neighbors").KNeighborsClassifier
    method.solver = LearningSolver(
        components = [
            MemorizingPrimalComponent(
                clf = KNN(n_neighbors = 30),
                extractor = H5FieldsExtractor(
                    instance_fields = ["static_var_obj_coeffs"],
                ),
                constructor = MergeTopSolutions(30, [0.0, 1.0]),
                action = FixVariables(),
            ),
        ],
    )
    return
end

function collect!(filenames::Vector, method::MIPLearnMethod)
    build(x) = _build_ucjl_model(x, method)
    if method.collectors === nothing
        _set_default_collectors!(method)
    end
    for c in method.collectors
        c.collect(filenames, build)
    end
end

function fit!(filenames::Vector, method::MIPLearnMethod)
    if method.solver === nothing
        _set_default_solver!(method)
    end
    return method.solver.fit(filenames)
end

function optimize!(filename::AbstractString, method::MIPLearnMethod)
    build(x) = _build_ucjl_model(x, method)
    method.solver.optimize(filename, build)
    return
end

function optimize!(instance::UnitCommitmentInstance, method::MIPLearnMethod)
    model = _build_ucjl_model(instance, method)
    method.solver.optimize(model)
    return
end