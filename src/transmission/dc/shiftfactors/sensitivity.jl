# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using SparseArrays, Base.Threads, LinearAlgebra, JuMP

"""
    _injection_shift_factors(; buses, branches)

Returns a (B-1)xL matrix M, where B is the number of buses and L is the number
of branches. For a given bus b and branch l, the entry M[l.offset, b.offset]
indicates the amount of power (in MW) that flows through branch l when 1 MW of
power is injected at b and withdrawn from the slack bus (the bus that has offset
zero).
"""
function _injection_shift_factors(; buses::Array{Bus}, branches::Array{Branch})
    susceptance = _susceptance_matrix(branches)
    incidence = _reduced_incidence_matrix(buses = buses, branches = branches)
    laplacian = transpose(incidence) * susceptance * incidence
    isf = susceptance * incidence * inv(Array(laplacian))
    return isf
end

"""
    _reduced_incidence_matrix(; buses::Array{Bus}, branches::Array{Branch})

Returns the incidence matrix for the network, with the column corresponding to
the slack bus is removed. More precisely, returns a (B-1) x L matrix, where B
is the number of buses and L is the number of branches. For each row, there is a 1
element and a -1 element, indicating the source and target buses, respectively,
for that branch.
"""
function _reduced_incidence_matrix(; buses::Array{Bus}, branches::Array{Branch})
    matrix = spzeros(Float64, length(branches), length(buses) - 1)
    for branch in branches
        if branch.source.offset > 0
            matrix[branch.offset, branch.source.offset] = 1
        end
        if branch.target.offset > 0
            matrix[branch.offset, branch.target.offset] = -1
        end
    end
    return matrix
end

"""
    _susceptance_matrix(branches::Array{Branch})

Returns a LxL diagonal matrix, where each diagonal entry is the susceptance of
the corresponding branch.
"""
function _susceptance_matrix(branches::Array{Branch})
    return Diagonal([b.susceptance for b in branches])
end

"""

    _line_outage_factors(; buses, branches, isf)

Returns a LxL matrix containing the Line Outage Distribution Factors (LODFs)
for the given network. This matrix how does the pre-contingency flow change
when each individual branch is removed.
"""
function _line_outage_factors(;
    buses::Array{Bus,1},
    branches::Array{Branch,1},
    isf::Array{Float64,2},
)::Array{Float64,2}
    incidence =
        Array(_reduced_incidence_matrix(branches = branches, buses = buses))
    lodf::Array{Float64,2} = isf * transpose(incidence)
    _, n = size(lodf)
    for i in 1:n
        lodf[:, i] *= 1.0 / (1.0 - lodf[i, i])
        lodf[i, i] = -1
    end
    return lodf
end
