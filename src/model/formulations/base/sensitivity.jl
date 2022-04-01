# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using SparseArrays, Base.Threads, LinearAlgebra, JuMP

"""
    _injection_shift_factors(; buses, lines)

Returns a (B-1)xL matrix M, where B is the number of buses and L is the number
of transmission lines. For a given bus b and transmission line l, the entry
M[l.offset, b.offset] indicates the amount of power (in MW) that flows through
transmission line l when 1 MW of power is injected at the slack bus (the bus
that has offset zero) and withdrawn from b.
"""
function _injection_shift_factors(;
    buses::Array{Bus},
    lines::Array{TransmissionLine},
)
    susceptance = _susceptance_matrix(lines)
    incidence = _reduced_incidence_matrix(lines = lines, buses = buses)
    laplacian = transpose(incidence) * susceptance * incidence
    isf = susceptance * incidence * inv(Array(laplacian))
    return isf
end

"""
    _reduced_incidence_matrix(; buses::Array{Bus}, lines::Array{TransmissionLine})

Returns the incidence matrix for the network, with the column corresponding to
the slack bus is removed. More precisely, returns a (B-1) x L matrix, where B
is the number of buses and L is the number of lines. For each row, there is a 1
element and a -1 element, indicating the source and target buses, respectively,
for that line.
"""
function _reduced_incidence_matrix(;
    buses::Array{Bus},
    lines::Array{TransmissionLine},
)
    matrix = spzeros(Float64, length(lines), length(buses) - 1)
    for line in lines
        if line.source.offset > 0
            matrix[line.offset, line.source.offset] = 1
        end
        if line.target.offset > 0
            matrix[line.offset, line.target.offset] = -1
        end
    end
    return matrix
end

"""
    _susceptance_matrix(lines::Array{TransmissionLine})

Returns a LxL diagonal matrix, where each diagonal entry is the susceptance of
the corresponding transmission line.
"""
function _susceptance_matrix(lines::Array{TransmissionLine})
    return Diagonal([l.susceptance for l in lines])
end

"""

    _line_outage_factors(; buses, lines, isf)

Returns a LxL matrix containing the Line Outage Distribution Factors (LODFs)
for the given network. This matrix how does the pre-contingency flow change
when each individual transmission line is removed.
"""
function _line_outage_factors(;
    buses::Array{Bus,1},
    lines::Array{TransmissionLine,1},
    isf::Array{Float64,2},
)::Array{Float64,2}
    incidence = Array(_reduced_incidence_matrix(lines = lines, buses = buses))
    lodf::Array{Float64,2} = isf * transpose(incidence)
    _, n = size(lodf)
    for i in 1:n
        lodf[:, i] *= 1.0 / (1.0 - lodf[i, i])
        lodf[i, i] = -1
    end
    return lodf
end
