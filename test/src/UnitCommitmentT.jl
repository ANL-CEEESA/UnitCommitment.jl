module UnitCommitmentT

using JuliaFormatter
using UnitCommitment
using Test

"""
Define a test function with an embedded `@testset` of the same name.
"""
macro testfunction(name, body)
    name_str = string(name)
    quote
        function $(esc(name))()
            @testset $name_str begin
                $(esc(body))
            end
        end
    end
end

macro test_binary_var(x)
    return quote
        let var = $(esc(x))
            @test var isa VariableRef
            @test is_binary(var)
        end
    end
end

macro test_integer_var(x, lb = nothing, ub = nothing)
    return quote
        let var = $(esc(x)), lb = $(esc(lb)), ub = $(esc(ub))
            @test var isa VariableRef
            @test is_integer(var)
            if lb === nothing
                @test !has_lower_bound(var)
            else
                @test has_lower_bound(var)
                @test JuMP.lower_bound(var) ≈ lb
            end
            if ub === nothing
                @test !has_upper_bound(var)
            else
                @test has_upper_bound(var)
                @test JuMP.upper_bound(var) ≈ ub
            end
        end
    end
end

macro test_continuous_var(x, lb = nothing, ub = nothing)
    return quote
        let var = $(esc(x)), lb = $(esc(lb)), ub = $(esc(ub))
            @test var isa VariableRef
            @test !is_binary(var)
            @test !is_integer(var)
            if lb === nothing
                @test !has_lower_bound(var)
            else
                @test has_lower_bound(var)
                @test JuMP.lower_bound(var) ≈ lb
            end
            if ub === nothing
                @test !has_upper_bound(var)
            else
                @test has_upper_bound(var)
                @test JuMP.upper_bound(var) ≈ ub
            end
        end
    end
end

macro test_obj_coef(var, expected)
    return quote
        let v = $(esc(var)), e = $(esc(expected))
            obj = objective_function(JuMP.owner_model(v))
            coef = JuMP.coefficient(obj, v)
            @test coef ≈ e atol = 1e-6
        end
    end
end

macro test_aff_expr(expr, var, expected)
    return quote
        @test JuMP.coefficient($(esc(expr)), $(esc(var))) ≈ $(esc(expected)) atol =
            1e-6
    end
end

macro test_constr(expr, rhs)
    # Extract constraint name from model[:constraint_name][indices...]
    model_ref = expr.args[1]
    name_sym = model_ref.args[2]
    if name_sym isa QuoteNode
        name_sym = name_sym.value
    end
    name_str = string(name_sym)

    # Extract and format indices (strings without quotes, others as-is)
    indices = expr.args[2:end]
    indices_str =
        join([idx isa String ? idx : string(idx) for idx in indices], ",")

    # Build expected string: "name[indices] : rhs"
    expected = "$name_str[$indices_str] : $rhs"

    return quote
        @test repr($(esc(expr))) == $expected
    end
end

# include("usage.jl")
# include("instance/read_test.jl")
# include("instance/migrate_test.jl")
# include("solution/methods/XavQiuWanThi19/filter_test.jl")
# include("solution/methods/XavQiuWanThi19/find_test.jl")
# include("solution/methods/XavQiuWanThi19/sensitivity_test.jl")
# include("solution/methods/ProgressiveHedging/usage_test.jl")
# include("solution/methods/TimeDecomposition/initial_status_test.jl")
# include("solution/methods/TimeDecomposition/optimize_test.jl")
# include("solution/methods/TimeDecomposition/update_solution_test.jl")
# include("transform/initcond_test.jl")
# include("transform/slice_test.jl")
# include("transform/randomize/XavQiuAhm2021_test.jl")
# include("validation/repair_test.jl")
# include("lmp/conventional_test.jl")
# include("lmp/aelmp_test.jl")
# include("market/market_test.jl")
# include("planning/planning_test.jl")
# include("regression.jl")
include("model/base/bus_test.jl")
include("model/base/thermal_test.jl")
include("model/base/profiled_test.jl")
include("model/base/psload_test.jl")
include("model/base/storage_test.jl")
include("model/transmission/phaseangle_test.jl")
include("model/model_MorLatRam2013_test.jl")
include("model/model_KnuOstWat2018_test.jl")

basedir = dirname(@__FILE__)

function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

function runtests()
    # println("Running tests...")
    # UnitCommitment._setup_logger(level = Base.CoreLogging.Error)
    @testset "UnitCommitment" begin
        @testset "model" begin
            model_base_bus_test()
            model_base_thermal_test()
            model_base_profiled_test()
            model_base_psload_test()
            model_base_storage_test()
            model_MorLatRam2013_test()
            model_KnuOstWat2018_test()
        end
        # model_planning_test()
        # usage_test()
        # instance_read_test()
        # instance_migrate_test()
        # solution_methods_XavQiuWanThi19_filter_test()
        # solution_methods_XavQiuWanThi19_find_test()
        # solution_methods_XavQiuWanThi19_sensitivity_test()
        # solution_methods_ProgressiveHedging_usage_test()
        # solution_methods_TimeDecomposition_initial_status_test()
        # solution_methods_TimeDecomposition_optimize_test()
        # solution_methods_TimeDecomposition_update_solution_test()
        # transform_initcond_test()
        # transform_slice_test()
        # # transform_randomize_XavQiuAhm2021_test()
        # validation_repair_test()
        # lmp_conventional_test()
        # lmp_aelmp_test()
        # simple_market_test()
        # stochastic_market_test()
        # regression_test()
    end
    return
end

function format()
    JuliaFormatter.format(basedir, verbose = true)
    JuliaFormatter.format("$basedir/../../src", verbose = true)
    JuliaFormatter.format("$basedir/../../docs/src", verbose = true)
    return
end

export runtests, format

end # module UnitCommitmentT
