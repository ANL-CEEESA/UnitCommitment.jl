using JuliaFormatter
print(pwd())
format(
    [
        "../../src", 
        "../../test",
        "../../benchmark/run.jl",
    ],
    verbose=true,
)
