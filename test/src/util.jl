# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020-2026, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

basedir = dirname(@__FILE__)

"""
    fixture(path) :: String

Return the absolute path to a test fixture file.
"""
function fixture(path::String)::String
    return "$basedir/../fixtures/$path"
end

"""
    test_optimizer()

Return a HiGHS optimizer with console logging disabled.
"""
function test_optimizer()
    return optimizer_with_attributes(HiGHS.Optimizer, "log_to_console" => false)
end

"""
    @testfunction name begin ... end

Define and export a zero-argument test function that wraps its body in a `@testset`.
"""
const _TESTFUNCTION_NAME_WIDTH = 80

macro testfunction(name, body)
    name_str = string(name)
    quote
        function $(esc(name))()
            local t0 = time()
            local ts = @testset $name_str begin
                $(esc(body))
            end
            local elapsed = time() - t0
            printstyled(
                rpad($name_str, $_TESTFUNCTION_NAME_WIDTH),
                color = :cyan,
            )
            if _testset_passed(ts)
                printstyled("PASS", color = :green, bold = true)
            else
                printstyled("FAIL", color = :red, bold = true)
            end
            printstyled(
                " ($(round(elapsed, digits=2))s)\n",
                color = :light_black,
            )
            return flush(stdout)
        end
        export $(esc(name))
    end
end

function _testset_passed(ts::Test.DefaultTestSet)
    for r in ts.results
        if r isa Test.Fail || r isa Test.Error
            return false
        elseif r isa Test.DefaultTestSet
            _testset_passed(r) || return false
        end
    end
    return true
end

"""
    @test_binary_var(x)

Assert that `x` is a binary `VariableRef`.
"""
macro test_binary_var(x)
    return quote
        let var = $(esc(x))
            @test var isa VariableRef
            @test is_binary(var)
        end
    end
end

"""
    @test_integer_var(x, lb=nothing, ub=nothing)

Assert that `x` is an integer `VariableRef`. If `lb` or `ub` are provided, check that
the variable has the given bound; otherwise, check that it is unbounded in that direction.
"""
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

"""
    @test_continuous_var(x, lb=nothing, ub=nothing)

Assert that `x` is a continuous `VariableRef`. If `lb` or `ub` are provided, check that
the variable has the given bound; otherwise, check that it is unbounded in that direction.
"""
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

"""
    @test_obj_coef(var, expected)

Assert that the objective coefficient of `var` equals `expected` (atol=1e-6).
"""
macro test_obj_coef(var, expected)
    return quote
        let v = $(esc(var)), e = $(esc(expected))
            obj = objective_function(JuMP.owner_model(v))
            coef = JuMP.coefficient(obj, v)
            @test coef ≈ e atol = 1e-6
        end
    end
end

"""
    @test_aff_expr(expr, var, expected)

Assert that the coefficient of `var` in affine expression `expr` equals `expected` (atol=1e-6).
"""
macro test_aff_expr(expr, var, expected)
    return quote
        @test JuMP.coefficient($(esc(expr)), $(esc(var))) ≈ $(esc(expected)) atol =
            1e-6
    end
end

"""
    @test_constr(model[:name][indices...], rhs, digits=nothing)

Assert that the string representation of a constraint matches `"name[indices] : rhs"`.
When `digits` is provided, all floating-point numbers in both strings are rounded before
comparing, allowing approximate coefficient matching.
"""
macro test_constr(expr, rhs, digits = nothing)
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
        let digits = $(esc(digits))
            if digits === nothing
                @test repr($(esc(expr))) == $expected
            else
                @test _round_floats(repr($(esc(expr))), digits) ==
                      _round_floats($expected, digits)
            end
        end
    end
end

function _round_floats(s::String, digits::Int)::String
    return replace(
        s,
        r"\d+\.\d+" => m -> string(round(parse(Float64, m), digits = digits)),
    )
end
