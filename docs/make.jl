using Documenter, UnitCommitment, JuMP

function make()
    return makedocs(
        sitename = "UnitCommitment.jl",
        pages = [
            "Home" => "index.md",
            "Tutorials" => [
                "tutorials/usage.md",
                "tutorials/customizing.md",
                "tutorials/market.md",
                "tutorials/decomposition.md",
            ],
            "User guide" => [
                "guides/problem.md",
                "guides/format.md",
                "guides/instances.md",
                "guides/model.md",
            ],
            "api.md",
        ],
        format = Documenter.HTML(assets = ["assets/custom.css"]),
    )
end