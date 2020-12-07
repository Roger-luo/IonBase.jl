const TEST_UUID = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

"""
    Tests(; file=".ion/templates/package/test/runtests.jl", project=false)

Sets up testing for packages.

## Keyword Arguments
- `file::AbstractString`: PackagePlan file for `runtests.jl`.
- `project::Bool`: Whether or not to create a new project for tests (`test/Project.toml`).
  See [here](https://julialang.github.io/Pkg.jl/v1/creating-packages/#Test-specific-dependencies-in-Julia-1.2-and-above-1)
  for more details.

!!! note
    Managing test dependencies with `test/Project.toml` is only supported
    in Julia 1.2 and later.
"""
@plugin struct Tests <: FilePlugin
    file::String = default_file("test", "runtests.jl")
    project::Bool = false
end

source(p::Tests) = p.file
destination(::Tests) = joinpath("test", "runtests.jl")
view(::Tests, ::PackagePlan, pkg::AbstractString) = Dict("PKG" => pkg)

function validate(p::Tests, t::PackagePlan)
    invoke(validate, Tuple{FilePlugin, PackagePlan}, p, t)
    p.project && t.julia < v"1.2" && @warn string(
        "Tests: The project option is set to create a project (supported in Julia 1.2 and later) ",
        "but a Julia version older than 1.2 ($(t.julia)) is supported by the template",
    )
end

function hook(p::Tests, t::PackagePlan, pkg_dir::AbstractString)
    # Do the normal FilePlugin behaviour to create the test script.
    invoke(hook, Tuple{FilePlugin, PackagePlan, AbstractString}, p, t, pkg_dir)

    # Then set up the test depdendency in the chosen way.
    if p.project
        make_test_project(pkg_dir::AbstractString)
    else
        add_test_dependency(t, pkg_dir)
    end
end

# Create a new test project.
function make_test_project(pkg_dir::AbstractString)
    open(joinpath(pkg_dir, "Project.toml"), "w") do io
        d = Dict{String, Any}(
            "deps" => Dict{String, Any}(
                "Test" => "8dfed614-e22c-5e08-85e1-65c5234f0b40"
            )
        )
        TOML.print(io, d)
    end
end

# Add Test as a test-only dependency.
function add_test_dependency(t::PackagePlan, pkg_dir::AbstractString)
    # Add the dependency manually since there's no programmatic way to add to [extras].
    path = joinpath(pkg_dir, "Project.toml")
    toml = TOML.parsefile(path)
    get!(toml, "extras", Dict())["Test"] = TEST_UUID
    get!(toml, "targets", Dict())["test"] = ["Test"]
    open(io -> TOML.print(io, toml), path, "w")

    # Generate the manifest by updating the project.
    # This also ensures that keys in Project.toml are sorted properly.
    touch(joinpath(pkg_dir, "Manifest.toml"))  # File must exist to be modified by Pkg.
    cd(pkg_dir) do
        PkgCmd.withproject("Pkg.update()", false, "update manifest", true, t.ion)
    end
end
