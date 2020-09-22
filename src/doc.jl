"""
documentation tools.
"""
module Doc

using Comonicon
using Pkg
using LiveServer: servedocs

"""
build documentation.

# Args

- `path`: path of the project.
"""
@cast function build(path::String=pwd())
    project_dir = dirname(Base.current_project(path))
    docs_dir = joinpath(project_dir, "docs")

    # with project
    old_project = Pkg.project().path
    Pkg.activate(docs_dir)
    Pkg.develop(path=project_dir)
    Pkg.instantiate()
    # with ARGS
    old_ARGS = copy(ARGS)
    empty!(ARGS)
    push!(ARGS, "local")
    Main.include(joinpath(docs_dir, "make.jl"))
    return
end

"""
serve documentation.

# Options

- `--foldername <name>`: specify the name of the content folder if different than "docs".
- `--literate <path>`: is the path to the folder containing the literate scripts, if 
    left empty, it will be assumed that they are in docs/src.

# Flags

- `--verbose`: show verbose log.
- `--doc-env`: is a boolean switch to make the server start by activating the 
    doc environment or not (i.e. the Project.toml in docs/).
"""
@cast function serve(;verbose::Bool=false, literate="", foldername="docs")
    servedocs(;verbose=verbose, literate=literate, doc_env=true, foldername=abspath(foldername))
end

end

@cast Doc
