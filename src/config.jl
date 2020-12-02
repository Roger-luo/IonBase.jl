module Options

using ..IonBase: dot_ion, ion_toml, init_dot_ion, templates
using Configurations
using Comonicon.Tools: cmd_error
using Pkg.Types: VersionSpec

function default_install_dir()
    haskey(ENV, "JULIA_INSTALL_PATH") && return ENV["JULIA_INSTALL_PATH"]
    install_dir = dot_ion("packages")
    if !ispath(install_dir)
        mkpath(install_dir)
    end
    return install_dir
end

@option mutable struct Julia
    active::Union{String, Nothing} = nothing
    stable::Union{VersionNumber, Nothing} = nothing
    nightly::Union{String, Nothing} = nothing
    install_dir::String = default_install_dir()
    # NOTE: we store nightly here too
    versions::Dict{VersionNumber, String} = Dict{VersionNumber, String}()
end

@option struct Plugins
    template::Vector{String} = String[]
    registry::Vector{String} = String[]
end

@option mutable struct Ion
    username::String = ""
    julia::Julia = Julia()
    plugins::Plugins = Plugins()
    default_template::String = "basic"
    templates::Dict{String, String} = Dict{String, String}(
        "basic" => templates("basic.toml"),
        "package" => templates("package.toml"),
        "academic" => templates("academic.toml"),
        "comonicon" => templates("comonicon.toml"),
        "comonicon-sysimg" => templates("comonicon-sysimg.toml"),
    )
end

function Configurations.option_convert(::Type{Julia}, ::Type{Dict{VersionNumber, String}}, x::Dict{String})
    d = Dict{VersionNumber, String}()
    for (k, v) in x
        d[VersionNumber(k)] = string(v)
    end
    return d
end

function load_plugins(m::Module, type::Symbol, ion::Ion=read())
    ex = Expr(:using)
    for each in getfield(ion.plugins, type)
        push!(ex.args, Expr(:(.), Symbol(each)))
    end
    Base.eval(m, ex)
    return
end

function read()::Ion
    if !ispath(ion_toml())
        return Ion()
    else
        return from_toml(Ion, ion_toml())
    end
end

# let's just pirate this
Base.String(x::VersionNumber) = string(x)
Base.convert(::Type{VersionNumber}, x::String) = VersionNumber(x)

toml_convert(x) = x

function toml_convert(x::VersionNumber)
    string(x)
end

function dump(option::Ion)
    init_dot_ion() # make sure .ion is avialable
    to_toml(toml_convert, ion_toml(), option)
    return
end

function withion(f)
    ion = read()
    ret = f(ion)
    dump(ion)
    return ret
end

function find_julia_bin(version::String="stable", option::Ion=read())
    find_julia_bin(version, option.julia)
end

function find_version(spec::String, versions)
    version_spec = VersionSpec(spec)
    curr = nothing
    for each in versions
        if each in version_spec && (curr === nothing || curr <= each)
            curr = each
        end
    end

    return curr
end

function find_julia_bin(version_string::String, option::Julia)
    if version_string == "stable"
        option.stable === nothing && return
        version_string = string(option.stable)
    elseif version_string == "latest" || version_string == "nightly"
        return option.nightly
    end

    match = find_version(version_string, keys(option.versions))
    match === nothing && return
    return option.versions[match]
end

function active_julia_bin(ion::Ion=read())::String
    # 1. use user specified julia binary
    if haskey(ENV, "JULIA_EXECUTABLE_PATH")
        return ENV["JULIA_EXECUTABLE_PATH"]
    end

    if !isnothing(ion.julia.active)
        return ion.julia.active
    end

    cmd_error(
        "cannot detect julia binary, " *
        "please install julia using: ion install julia [--version=stable] " *
        "or specify via environment variable JULIA_EXECUTABLE_PATH"
    )
end

function active_julia_depots(ion::Ion=read())::Vector{String}
    julia_bin = active_julia_bin(ion)
    return withenv("JULIA_PROJECT"=>nothing, "JULIA_LOAD_PATH"=>nothing, "JULIA_DEPOT_PATH"=>nothing) do
        Base.eval(Meta.parse(readchomp(`$julia_bin -E 'using Pkg; Pkg.Types.depots()'`)))
    end
end

end # Options
