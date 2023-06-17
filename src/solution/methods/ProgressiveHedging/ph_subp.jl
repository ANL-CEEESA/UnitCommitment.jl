using MPI: MPI_Info, push!
using Gurobi, JuMP, MPI, Glob, DelimitedFiles, Printf, UnitCommitment
const TEMPDIR = tempdir()
input_path = "$(TEMPDIR)/input_files/new_scenarios"

function _write_results(
    final_result::UnitCommitment.PHFinalResult,
    solution_path::String,
)::Nothing
    rank = UnitCommitment.MpiInfo(MPI.COMM_WORLD).rank
    rank_solution_path = "$(solution_path)/$(rank)"
    mkpath(rank_solution_path)
    if rank == 1
        open("$(rank_solution_path)/global_obj.txt", "w") do file
            return Base.write(file, @sprintf("%s", final_result.obj))
        end
        open("$(rank_solution_path)/wallclock_time.txt", "w") do file
            return Base.write(file, @sprintf("%s", final_result.wallclock_time))
        end
        writedlm(
            "$(rank_solution_path)/binary_vals.csv",
            final_result.vals,
            ',',
        )
    end
end
open("$(input_path)/setup.txt") do snum
    return global system, s_num, r = split(Base.read(snum, String), ",")
end
new_scenario_path = "$(input_path)/$(system)/snum_$(s_num)/run_$r/"
solution_path = "$(TEMPDIR)/output_files/$(system)/snum_$(s_num)/run_$r"
MPI.Init()
ph = UnitCommitment.ProgressiveHedging()
instance = UnitCommitment.read(glob("*.json", new_scenario_path), ph)
model = UnitCommitment.build_model(
    instance = instance,
    optimizer = Gurobi.Optimizer,
)
final_result = UnitCommitment.optimize!(model, ph)
_write_results(final_result, solution_path)
MPI.Finalize()
