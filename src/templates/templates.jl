# this is a custom fork of PkgTemplates
module Templates

using LibGit2: LibGit2, GitConfig, GitReference, GitRemote, GitRepo, delete_branch
using UUIDs: uuid4
using Mustache: render
using Configurations: Configurations, field_default, @option, from_dict
using OrderedCollections: OrderedDict
using Pkg: Pkg, PackageSpec
using TOML
using Comonicon.Parse: default_name
using InteractiveUtils: subtypes
using Dates: month, today, year

using ..IonBase: templates
using ..PkgCmd
using ..Options

export Template, PackagePlan, 
    AppVeyor,
    BlueStyleBadge,
    CirrusCI,
    Citation,
    Codecov,
    ColPracBadge,
    CompatHelper,
    Coveralls,
    Documenter,
    DroneCI,
    Git,
    GitHubActions,
    GitLabCI,
    License,
    Logo,
    NoDeploy,
    ProjectFile,
    Readme,
    Secret,
    SrcDir,
    TagBot,
    Tests,
    TravisCI,
    Comonicon,
    SystemImage

abstract type Plugin end

struct Template
    name::String
    plugins::Vector{Plugin}
end

function Template(file::String)
    d = TOML.parsefile(file)
    haskey(d, "name") || throw(ArgumentError("template must have field name"))
    plugins = collect_plugins(d)
    return Template(d["name"], plugins)
end

function Configurations.toml(to_toml, io::IO, t::Template; sorted::Bool=false, by=identity)
    d = OrderedDict{String, Any}("name" => t.name)
    for plugin in t.plugins
        P = typeof(plugin)
        alias = Configurations.alias(P)
        name = alias === nothing ? string(nameof(P)) : alias
        plugin_dict = Configurations.dictionalize(plugin)
        d[name] = plugin_dict
    end
    TOML.print(to_toml, io, d; sorted=sorted, by=by)
    return
end

function collect_plugins!(plugins::Vector{Any}, ::Type{T}, d::AbstractDict{String}) where T
    for each in subtypes(T)
        if isabstracttype(each)
            collect_plugins!(plugins, each, d)
            continue
        end
        
        alias = Configurations.alias(each)
        name = alias === nothing ? string(nameof(each)) : alias
        if name in keys(d)
            push!(plugins, from_dict(each, d[name]))
        end
    end
    return plugins
end

function collect_plugins(d::AbstractDict{String})
    return collect_plugins!([], Plugin, d)
end

struct PackagePlan
    template::Template
    name::String
    user::String
    authors::Vector{String}
    host::String
    julia::VersionNumber
    ion::Options.Ion

    function PackagePlan(t::Template, name::String, user::String, authors::Vector{String}, host::String, julia::VersionNumber, ion::Options.Ion = Options.read())
        endswith(name, ".jl") && (name = name[1:end-3])
        host = replace(host, r".*://" => "")
        new(t, name, user, authors, host, julia, ion)
    end
end

function PackagePlan(template::String, name::String, user::String, authors::Vector{String}, host::String, julia::VersionNumber, ion::Options.Ion = Options.read())
    haskey(ion.templates, template) || throw(ArgumentError("cannot find template: $template"))
    t = Template(ion.templates[template])
    return PackagePlan(t, name, user, authors, host, julia, ion)
end

function create(pkg::PackagePlan, path::String=pwd(), force::Bool=false)
    pkg_dir = joinpath(abspath(expanduser(path)), pkg.name)
    ispath(pkg_dir) && !force && throw(ArgumentError("$pkg_dir already exists"))
    if force && ispath(pkg_dir)
        rm(pkg_dir; force=true, recursive=true)
    end
    mkpath(pkg_dir)

    try
        foreach((prehook, hook, posthook)) do h
            @info "Running $(nameof(h))s"
            foreach(sort(pkg.template.plugins; by=p -> priority(p, h), rev=true)) do p
                h(p, pkg, pkg_dir)
            end
        end
    catch
        rm(pkg_dir; recursive=true, force=true)
        rethrow()
    end

    @info "New package is at $pkg_dir"
end

hasplugin(t::PackagePlan, f::Function) = any(f, t.template.plugins)
hasplugin(t::PackagePlan, ::Type{T}) where T <: Plugin = hasplugin(t, p -> p isa T)

"""
    getplugin(t::PackagePlan, ::Type{T<:Plugin}) -> Union{T, Nothing}

Get the plugin of type `T` from the template `t`, if it's present.
"""
function getplugin(t::PackagePlan, ::Type{T}) where T <: Plugin
    i = findfirst(p -> p isa T, t.template.plugins)
    return i === nothing ? nothing : t.template.plugins[i]
end

function default_branch(t::PackagePlan)
    git = getplugin(t, Git)
    return git === nothing ? nothing : git.branch
end

function find_username(ion::Options.Ion=Options.read())
    username = LibGit2.getconfig("github.user", ion.username)
    isempty(username) || return username
    input = Base.prompt("Enter value for 'username' (String, required)")
    input === nothing && cmd_error("invalid username")
    return input
end

function default_authors()
    name = LibGit2.getconfig("user.name", "")
    isempty(name) && return "contributors"
    email = LibGit2.getconfig("user.email", "")
    authors = isempty(email) ? name : "$name <$email>"
    return ["$authors and contributors"]
end

include("plugin.jl")

end

"""
create a project or package.

# Arguments

- `path`: path of the project you want to create

# Options

- `--user <name>`: your GitHub user name for this package.
- `--template <template name>`: template name.

# Flags

- `-f, --force`: force create a new project, remove `path` if it exists.
"""
@cast function create(path::String; user::String="", template::String="basic", authors::String="", host::String="github.com", force::Bool=false)
    ion = Options.read()
    isempty(user) && (user = find_username(ion))
    julia = Options.active_julia_version(ion)
    authors = isempty(authors) ? Templates.default_authors() : map(x->String(strip(x)), split(authors, ","))
    pkg = Templates.PackagePlan(template, basename(path), user, authors, host, julia, ion)
    Templates.create(pkg, isempty(dirname(path)) ? pwd() : dirname(path), force)
    return
end
