using Documenter, UnitCommitment, JuMP

makedocs(
    sitename="UnitCommitment.jl",
    pages=[
        "Home" => "index.md",
        "usage.md",
        "format.md",
        "instances.md",
        "model.md",
        "api.md",
    ],
    format = Documenter.HTML(
        assets=["assets/custom.css"],
    )
)
