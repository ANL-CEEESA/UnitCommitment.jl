# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

import Logging: min_enabled_level, shouldlog, handle_message
using Base.CoreLogging, Logging, Printf

struct TimeLogger <: AbstractLogger
    initial_time::Float64
    file::Union{Nothing,IOStream}
    screen_log_level::Any
    io_log_level::Any
end

function TimeLogger(;
    initial_time::Float64,
    file::Union{Nothing,IOStream} = nothing,
    screen_log_level = CoreLogging.Info,
    io_log_level = CoreLogging.Info,
)::TimeLogger
    return TimeLogger(initial_time, file, screen_log_level, io_log_level)
end

min_enabled_level(logger::TimeLogger) = logger.io_log_level
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
    elapsed_time = time() - logger.initial_time
    time_string = @sprintf("[%12.3f] ", elapsed_time)

    if level >= Logging.Error
        color = :light_red
    elseif level >= Logging.Warn
        color = :light_yellow
    else
        color = :light_green
    end

    if level >= logger.screen_log_level
        printstyled(time_string, color = color)
        println(message)
        flush(stdout)
        flush(stderr)
        Base.Libc.flush_cstdio()
    end
    if logger.file !== nothing && level >= logger.io_log_level
        write(logger.file, time_string)
        write(logger.file, message)
        write(logger.file, "\n")
        flush(logger.file)
    end
end

function _setup_logger()
    initial_time = time()
    return global_logger(TimeLogger(initial_time = initial_time))
end
