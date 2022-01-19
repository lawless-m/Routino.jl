using Documenter
using Routino
using Dates


makedocs(
    modules = [Routino],
    sitename="Routino.jl", 
    authors = "Matt Lawless",
    format = Documenter.HTML(),
)

deploydocs(
    repo = "github.com/lawless-m/Routino.jl.git", 
    devbranch = "main",
    push_preview = true,
)
