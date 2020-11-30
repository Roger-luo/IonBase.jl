module CreateCmd

using Crayons.Box
using PkgTemplates
using TOML
using Comonicon.Tools: prompt, cmd_error

using ..IonBase
using ..Options
using ..IonBase: templates

include("plugins/comonicon.jl")

using .ComoniconPlugin

function PkgTemplates.user_view(::Readme, t::Template, ::AbstractString)
    return Dict(
        "HAS_COMONICON" => PkgTemplates.hasplugin(t, Comonicon)
    )
end

const TOMLDict = Dict{String, Any}

function snake2camel(s::String; conventions::Dict{String, String}=Dict(
        "appveyor" => "AppVeyor",
        "github_actions" => "GitHubActions",
        "bluestyle" => "BlueStyle",
        "colprac" => "ColPrac",
        "gitlab_ci" => "GitLabCI",
        "cirrus_ci" => "CirrusCI",
        "travis_ci" => "TravisCI",
    ))

    s in keys(conventions) && return conventions[s]
    return join(uppercasefirst.(split(s, "_")))
end

function find_camel_split(s::String, start::Int = 0)
    prev = start
    prev_lowercase = false
    curr = start + 1
    while curr < ncodeunits(s)
        if prev_lowercase && isuppercase(s[curr])
            return prev_lowercase
        elseif islowercase(s[curr])
            prev_lowercase = true
        else
            prev_lowercase = false
        end

        prev = curr
        curr = nextind(s, curr)
    end
    return prev # end of string
end

function camel2snake(s::String; conventions::Dict{String, String}=Dict(
        "AppVeyor" => "appveyor",
        "GitHubActions" => "github_actions",
        "BlueStyleBadge" => "bluestyle",
        "ColPracBadge" => "colprac",
    ))
    s in keys(conventions) && return conventions[s]
    parts = SubString[]
    prev = 1
    curr = 0
    while prev <= ncodeunits(s)
        curr = find_camel_split(s, curr)
        push!(parts, s[prev, curr])
        prev = curr + 1
    end
    return join(lowercase.(parts), "_")
end

Base.convert(::Type{Secret}, x::String) = Secret(x)

function Base.convert(::Type{Logo}, x::Dict{String, Any})
    return Logo(;
        light = get(x, "light", nothing),
        dark = get(x, "dark", nothing),
    )
end

function copy_templates(dst::String)
    ispath(dst) || mkpath(dst)
    pkg_template_dir = joinpath(pkgdir(PkgTemplates), "templates")
    for (root, dirs, files) in walkdir(pkg_template_dir)
        for file in files
            if file in ["README.md"]
                continue
            else
                dst_dir = joinpath(dst, "package", relpath(root, pkg_template_dir))
                ispath(dst_dir) || mkpath(dst_dir)
                cp(joinpath(root, file), joinpath(dst_dir, file); force=true, follow_symlinks=true)
            end
        end
    end

    ion_template_dir = joinpath(pkgdir(IonBase), "templates")
    for (root, dirs, files) in walkdir(ion_template_dir)
        for file in files
            dst_dir = joinpath(dst, relpath(root, ion_template_dir))
            ispath(dst_dir) || mkpath(dst_dir)
            cp(joinpath(root, file), joinpath(dst_dir, file); force=true, follow_symlinks=true)
        end
    end
end

function push_plugin!(plugins::Vector{Any}, plugin_name::String, params::Dict{String, Any}, postfix::String="")
    name = Symbol(snake2camel(plugin_name) * postfix)
    isdefined(CreateCmd, name) || cmd_error("template plugin $name is not defined")
    kwargs = Expr(:parameters)
    for (k, v) in params
        push!(kwargs.args, Expr(:kw, Symbol(k), v))
    end
    ex = Expr(:call, name, kwargs)
    push!(plugins, Base.eval(CreateCmd, ex))
    return plugins
end

function read_template(file::String, ion::Options.Ion = Options.read())
    Options.load_plugins(CreateCmd, :template, ion)
    template = TOML.parsefile(file)
    plugins = Any[]
    for (plugin_name, params) in template
        if plugin_name in []
            # skip template meta
        elseif plugin_name == "project"
            push!(plugins, ProjectFile(;version=VersionNumber(get(params, "version", "0.1.0"))))
            # NOTE: we must specify the files here since we will
            # ship these files with the binary we build later
            # SrcDir
            file = get(params, "src", joinpath("package", "src", "module.jl"))
            if !isabspath(file)
                file = templates(file)
            end
            push!(plugins, SrcDir(;file=file))

            test = get(params, "test", nothing)
            test_file = joinpath("package", "test", "runtests.jl")
            test_project = false
            if !isnothing(test)
                test_file = get(test, "file", test_file)
                test_project = get(test, "project", test_project)
            end
            push!(plugins, Tests(;file=templates(test_file), project=test_project))
        elseif plugin_name == "license"
            name = get(params, "name", "MIT")
            destination = get(params, "destination", "LICENSE")
            path = get(params, "path", templates("package", "licenses", name))
            push!(plugins, License(;name, destination, path))
        elseif plugin_name == "badge"
            for (badge, badge_params) in params
                push_plugin!(plugins, badge, badge_params, "Badge")
            end
        elseif plugin_name == "documenter"
            if haskey(params, "logo")
                params["logo"] = convert(Logo, params["logo"])
            end

            if haskey(params, "make_jl")
                params["make_jl"] = templates(params["make_jl"])
            end

            if haskey(params, "index_md")
                params["index_md"] = templates(params["index_md"])
            end

            push_plugin!(plugins, plugin_name, params)
        else
            # TODO: we need a more extensible way to do this...
            #   maybe consider PR to PkgTemplates
            if haskey(params, "file")
                params["file"] = templates(params["file"])
            end

            push_plugin!(plugins, plugin_name, params)
        end
    end

    # NOTE: we remove default plugins for template.toml files
    # since we always explicitly specify what plugin we need
    if !haskey(template, "readme")
        push!(plugins, !Readme)
    end

    if !haskey(template, "license")
        push!(plugins, !License)
    end

    if !haskey(template, "git")
        push!(plugins, !Git)
    end

    if !haskey(template, "compat_helper")
        push!(plugins, !CompatHelper)
    end

    if !haskey(template, "tag_bot")
        push!(plugins, !TagBot)
    end
    return plugins
end

function create_template(path::String, user::String="", template::String="", interactive::Bool=false, ion::Options.Ion=Options.read())
    if isempty(template)
        template = ion.default_template::String
    end

    template = template * ".toml" # add ext
    if !isabspath(template) # use .ion/template/xx.toml
        template = templates(template)
    end

    plugins = read_template(template, ion)

    if isempty(user) # try to find username if not specified
        if isempty(ion.username)
            user = readchomp(`git config user.name`)
        else
            user = ion.username
        end
    end

    return Template(;
        user=user,
        interactive=interactive,
        dir=dirname(path),
        plugins = plugins,
    )
end

function read_terminal(msg::String)
    print(msg)
    input = readuntil(stdin, '\n')
    println()
    return input
end

function raise_meta(key::String)
    if key == "name"
        typemax(Int)
    else
        Int(first(key))
    end
end

function save_template(t::Template, ion::Options.Ion=Options.read(), name::String="")
    # TODO: move this to Comonicon
    if isempty(name)
        for _ in 1:3
            name = read_terminal("template name: ")
            file = name * ".toml"
            if ispath(file) || isfile(file)
                print("template name $name exists, use another name")
            else
                break
            end
        end
    else
        file = name * ".toml"
    end

    d = TOMLDict("name" => name)
    for each in t.plugins
        if each isa ProjectFile
            project = get(d, "project", TOMLDict())
            project["version"] = each.version
        elseif each isa SrcDir
            project["src"] = each.file
        else
            T = typeof(each)
            plugin_name = camel2snake(string(T))
            plugin = get(d, plugin_name, TOMLDict())
            for fname in fieldnames(T)
                # NOTE: we convert things to TOML type later
                plugin[string(fname)] = getfield(each, fname)
            end
        end
    end

    open(templates(name * ".toml"), "w+") do io
        TOML.print(to_toml, io, d; sorted=true, by=raise_meta)
    end

    # update meta
    ion.templates[name] = file
    return
end

function create(path::String, user::String="", template::String="", force::Bool=false, interactive::Bool=false)
    PkgTemplates.DEFAULT_TEMPLATE_DIR[] = templates("package")
    t = Options.withion() do ion
        t = create_template(path, user, template, interactive, ion)

        if interactive && prompt("do you want to save this template?")
            save_template(t, ion)
        end

        return t
    end

    if force && ispath(path)
        @info "$(CYAN_FG(path)) exists, removing..."
        rm(path; force=true, recursive=true)
    end
    t(basename(path))
    return
end

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
- `-i, --interactive`: enable to start interactive configuration interface.
"""
@cast function create(path::String; user::String="", template::String="", force::Bool=false, interactive::Bool=false)
    CreateCmd.create(path, user, template, force, interactive)
    return
end
