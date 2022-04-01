# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

function _offer(filter::_ViolationFilter, v::_Violation)::Nothing
    if v.monitored_line.offset ∉ keys(filter.queues)
        filter.queues[v.monitored_line.offset] = PriorityQueue{_Violation,Float64}()
    end
    q::PriorityQueue{_Violation,Float64} = filter.queues[v.monitored_line.offset]
    if length(q) < filter.max_per_line
        enqueue!(q, v => v.amount)
    else
        if v.amount > peek(q)[1].amount
            dequeue!(q)
            enqueue!(q, v => v.amount)
        end
    end
    return nothing
end

function _query(filter::_ViolationFilter)::Array{_Violation,1}
    violations = Array{_Violation,1}()
    time_queue = PriorityQueue{_Violation,Float64}()
    for l in keys(filter.queues)
        line_queue = filter.queues[l]
        while length(line_queue) > 0
            v = dequeue!(line_queue)
            if length(time_queue) < filter.max_total
                enqueue!(time_queue, v => v.amount)
            else
                if v.amount > peek(time_queue)[1].amount
                    dequeue!(time_queue)
                    enqueue!(time_queue, v => v.amount)
                end
            end
        end
    end
    while length(time_queue) > 0
        violations = [violations; dequeue!(time_queue)]
    end
    return violations
end
