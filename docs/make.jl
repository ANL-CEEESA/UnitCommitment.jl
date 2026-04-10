using Documenter
using UnitCommitment
using JuMP
using Literate



function make()
    literate_sources = [
        "src/tutorials/usage.jl",
        "src/tutorials/customizing.jl",
        "src/tutorials/market.jl",
    ]
    for src in literate_sources
        Literate.markdown(
            src,
            dirname(src);
            documenter = true,
            credit = false,
        )
    end
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
                "guides/input-format.md",
                "guides/output-format.md",
                "guides/instances.md",
                "guides/backend.md",
            ],
            "Experimental extensions" => [
                "guides/experimental/aelmp.md",
                "guides/experimental/flexiramp.md",
            ],
        ],
        format = Documenter.HTML(assets = ["assets/custom.css"]),
    )
end