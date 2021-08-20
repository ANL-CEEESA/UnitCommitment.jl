# UnitCommitment.jl: Optimization Package for Security-Constrained Unit Commitment
# Copyright (C) 2020, UChicago Argonne, LLC. All rights reserved.
# Released under the modified BSD license. See COPYING.md for more details.

using PackageCompiler
using TOML
using Logging

Logging.disable_logging(Logging.Info)
mkpath("build")

println("Generating precompilation statements...")
run(`julia --project=. --trace-compile=build/precompile.jl $(ARGS)`)

println("Finding dependencies...")
project = TOML.parsefile("Project.toml")
manifest = TOML.parsefile("Manifest.toml")
deps = Symbol[]
for dep in keys(project["deps"])
    if "path" in keys(manifest[dep][1])
        println("  - $(dep) [skip]")
    else
        println("  - $(dep)")
        push!(deps, Symbol(dep))
    end
end

println("Building system image...")
create_sysimage(
    deps,
    precompile_statements_file = "build/precompile.jl",
    sysimage_path = "build/sysimage.so",
)
