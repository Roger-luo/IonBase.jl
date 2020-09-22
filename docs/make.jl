using Documenter, IonBase

makedocs(;
    modules = [IonBase],
    format = Documenter.HTML(prettyurls = !("local" in ARGS)),
    pages = [
        "Home" => "index.md",
    ],
    repo = "https://github.com/Roger-luo/IonBase.jl",
    sitename = "IonBase.jl",
)

deploydocs(; repo = "github.com/Roger-luo/IonBase.jl")
