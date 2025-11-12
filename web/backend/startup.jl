# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using HiGHS
using JuMP
using Backend

const UCJL_HOST = get(ENV, "HOST", "0.0.0.0")
const UCJL_PORT = parse(Int, get(ENV, "PORT", "9000"))

println("Starting UnitCommitment Backend Server...")
println("Host: $UCJL_HOST")
println("Port: $UCJL_PORT")

Backend.setup_logger()
server = Backend.start_server(
    UCJL_HOST,
    UCJL_PORT;
    optimizer = optimizer_with_attributes(
        HiGHS.Optimizer, "mip_rel_gap" => 0.001,
        "threads" => 1,
    )
)
try
    wait()
catch e
    if e isa InterruptException
        println("\nShutting down server...")
        Backend.stop(server)
        println("Server stopped")
    else
        rethrow(e)
    end
end
