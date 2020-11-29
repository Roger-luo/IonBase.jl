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
- `args...`: command line arguments for `docs/make.jl`
"""
@cast function build(path::String=pwd(), args...)
    project_dir = dirname(Base.current_project(path))
    docs_dir = joinpath(project_dir, "docs")

    # with project
    old_project = Pkg.project().path
    Pkg.activate(docs_dir)
    Pkg.develop(path=project_dir)
    Pkg.instantiate()
    # with ARGS
    old_ARGS = copy(ARGS)
    copy!(ARGS, collect(args))

    Main.include(joinpath(docs_dir, "make.jl"))
    copy!(ARGS, old_ARGS)
    Pkg.activate(old_project)
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
- `-l, --launch-browser`: open documentation in default browser.
"""
@cast function serve(;verbose::Bool=false, literate="", foldername="docs", launch_browser::Bool=false)
    servedocs(;verbose=verbose, literate=literate, doc_env=true, foldername=abspath(foldername), launch_browser=launch_browser)
end

end

@cast Doc
