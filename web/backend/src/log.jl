# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2025, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Logging: min_enabled_level, shouldlog, handle_message
using Base.CoreLogging, Logging, Dates

struct TimeLogger <: AbstractLogger end

min_enabled_level(::TimeLogger) = CoreLogging.Info
shouldlog(logger::TimeLogger, level, _module, group, id) = true

function handle_message(
    logger::TimeLogger,
    level,
    message,
    _module,
    group,
    id,
    filepath,
    line;
    kwargs...,
)
    current_time = Dates.format(now(), "yyyy-mm-dd HH:MM:SS.sss")
    print("[$current_time] ")
    println(message)
    flush(stdout)
    flush(stderr)
    return Base.Libc.flush_cstdio()
end

function setup_logger()
    global_logger(TimeLogger())
    for pid in workers()
        @spawnat pid global_logger(TimeLogger())
    end
    return
end
