module ReleaseCmd

using LibGit2
using OrderedCollections
using UUIDs
using GitHub
using Crayons.Box
using TOML
using Pkg

using Pkg.Types: RegistrySpec
using Comonicon.Tools: prompt, cmd_error
using ..Options
using ..SearchCmd: find_max_version
using ..IonBase: read_github_auth, gitcmd

"""
    PRN{name}

Package Registry Name
"""
struct PRN{name} end

"""
    PRN(name::String)

Create a `PRN` (Pacakge Registry Name) object.
"""
PRN(name::String) = PRN{Symbol(name)}()

macro PRN_str(name::String)
    return PRN{Symbol(name)}
end

Base.show(io::IO, ::PRN{registry}) where {registry} = print(io, "Pacakge Registry ", string(registry))

Base.@kwdef struct VersionTokens
    major::String = "major"
    minor::String = "minor"
    patch::String = "patch"
end

const VERSION_TOKENS = VersionTokens()
Base.show(io::IO, vt::VersionTokens) = print(io, "(", vt.major, ", ", vt.minor, ", ", vt.patch, ")")

Base.in(version::String, tokens::VersionTokens) = (version == tokens.major) ||
    (version == tokens.minor) || (version == tokens.patch)

function is_version_number(version)
    occursin(r"[0-9]+.[0-9]+.[0-9]+", version) ||
        occursin(r"v[0-9]+.[0-9]+.[0-9]+", version)
end

struct Project
    path::String
    toml::String
    pkg::Pkg.Types.Project
    ion::Options.Ion
    git::Cmd
    branch::String
    quiet::Bool
end

function Project(path::String=pwd(); branch="master", quiet=false, ion::Options.Ion=Options.read())
    toml = Base.current_project(path)
    toml === nothing && cmd_error("cannot find (Julia)Project.toml in $path")
    path = dirname(toml)
    pkg = Pkg.Types.read_project(toml)
    git = gitcmd(path)
    return Project(path, toml, pkg, ion, git, branch, quiet)
end

Base.show(io::IO, p::Project) = print(io, "Project(", p.path, ")")

function current_branch(p::Project)
    return readchomp(`$(p.git) rev-parse --abbrev-ref HEAD`)
end

function commit_toml(project::Project; push::Bool=false)
    git = project.git
    version_number = project.pkg.version
    run(`$git add $(project.toml)`)
    run(`$git commit -m"bump version to $version_number"`)
    push && gitpush(project)
    return
end

function gitpush(project::Project)
    run(`$(project.git) push origin $(project.branch)`)
    println(DARK_GRAY_FG("="^80))
end

function reset_last_commit(project::Project; push=false)
    git = project.git
    run(`$git revert --no-edit --no-commit HEAD`)
    run(`$git commit -m "revert version bump due to an error occured in IonCLI"`)
    push && gitpush(project)
    return
end

function checkout(f, p::Project)
    old = current_branch(p)

    if old != p.branch
        @info "checking out to $(p.branch)"
        run(`$(p.git) checkout $(p.branch)`)
    end

    f()

    if old != p.branch
        run(`$(p.git) checkout $old`)
    end
end

function collect_registers(project::Project)
    depots = Options.active_julia_depots(project.ion)
    isempty(depots) && return RegistrySpec[]
    return RegistrySpec[r for d in depots for r in Pkg.Types.collect_registries(d)]
end

function query_project_registry(project::Project)
    registries = collect_registers(project)

    matches = filter(registries) do rs::RegistrySpec
        d = Pkg.Types.read_registry(joinpath(rs.path, "Registry.toml"))
        haskey(d["packages"], string(project.pkg.uuid))
    end

    isempty(matches) && return
    return matches
end

function register(registry::String, project::Project)
    if isempty(registry) # registered package
        matches = query_project_registry(project)
        matches === nothing && cmd_error(
            "$(project.pkg.name) is not registered " *
            "in local registries, please specify " *
            "registry name using --registry=<name>"
        )

        length(matches) == 1 || cmd_error(
            "this package is registered in the following registries: " *
            join([isnothing(each.name) ? "unknown" : each.name for each in matches], ", ") *
            "please specify registry name using --registry=<name>"
        )

        path = first(matches).path
        return register(PRN(basename(path)), project)
    else
        return register(PRN(registry), project)
    end
end

function register(registry::PRN, project::Project)
    cmd_error("register workflow is not defined for $registry")
end

function registrator_msg(project)
    msg = "Released via [Ion CLI](https://github.com/Roger-luo/IonCLI.jl)\n"
    # msg *= "@JuliaRegistrator register"
    msg *= "testing"
    if project.branch == "master"
        return msg
    else
        return msg * " branch=$(project.branch)"
    end
end

function read_head(git, branch="master")
    return readchomp(`$git rev-parse --verify HEAD`)
end

function read_remote_push(git, remote="origin")
    return readchomp(`$git config --get remote.$remote.url`)
end

function github_repo(git, remote="origin")
    url = read_remote_push(git, remote)
    github_https = "https://github.com/"
    github_ssh = "git@github.com:"
    if startswith(url, github_https)
        if endswith(url, ".git")
            return url[length(github_https)+1:end-4]
        else
            return url[length(github_https)+1:end]
        end
    elseif startswith(url, github_ssh)
        return url[length(github_ssh)+1:end-4]
    else
        return
    end
end

function update_version!(project::Project, version)
    if is_version_number(version)
        version_number = VersionNumber(version)
    elseif version in VERSION_TOKENS
        version_number = bump_version(project, version)
    else
        cmd_error("invalid version $version")
    end

    if !project.quiet
        latest_version = find_max_version(project.pkg.name)

        if latest_version === nothing
            println("package not found in local registries")
        else
            println("latest registered version: ", LIGHT_CYAN_FG(string(latest_version)))
            if latest_version > version_number
                @warn "input version is smaller than registered version"
            end
        end

        println(" "^10, "current version: ", LIGHT_CYAN_FG(string(project.pkg.version)))
        println(" "^7, "version to release: ", LIGHT_CYAN_FG(string(version_number)))
        if !prompt("do you want to update Project.toml?")
            exit(0)
        end
    end

    write_version(project, version_number)
    println(" ", LIGHT_GREEN_FG("✔"), "  Project.toml has been updated to ", LIGHT_CYAN_FG(string(version_number)))
    return project
end

function bump_version(project::Project, token::String)
    if project.pkg.version === nothing
        return bump_version(v"0.0.0", token)
    else
        return bump_version(project.pkg.version, token)
    end
end

function bump_version(version::VersionNumber, token::String)
    if token == VERSION_TOKENS.major
        return VersionNumber(version.major+1, 0, 0)
    elseif token == VERSION_TOKENS.minor
        return VersionNumber(version.major, version.minor+1, 0)
    elseif token == VERSION_TOKENS.patch
        return VersionNumber(version.major, version.minor, version.patch+1)
    else
        cmd_error("invalid token $token")
    end
end

function write_version(project::Project, version::VersionNumber)
    project.pkg.version = version
    open(project.toml, "w+") do f # following whatever Pkg does
        TOML.print(f, to_dict(project); sorted=true, by=key -> (Pkg.Types.project_key_order(key), key)) do x
            if x isa UUID || x isa VersionNumber
                x = string(x)
            end
            x
        end
    end
end

to_dict(p::Project) = to_dict(p.pkg)

function to_dict(project::Pkg.Types.Project)
    project_keys = [:name, :uuid, :authors, :version, :deps, :compat, :extras, :targets]
    t = []
    for key in project_keys
        push_maybe!(t, project, key)
    end

    # write other part back
    for key in keys(project.other)
        if !(key in string.(project_keys))
            push!(t, project.other[key])
        end
    end
    return OrderedDict(t)
end

function push_maybe!(t::Vector, project::Pkg.Types.Project, name::Symbol)
    key = string(name)
    if hasfield(Pkg.Types.Project, name)
        member = getfield(project, name)
        if member !== nothing
            push!(t, key => member)
        end
    else
        member = get(project.other, key, nothing)
        if member !== nothing
            push!(t, key => member)
        end
    end
    return t
end

function release(version::String, path::String=pwd(), registry="", branch="master")
    project = Project(path; branch=branch)
    # new version needs to be pushed
    # so the JuliaRegistrator can find
    # it later
    checkout(project) do
        if LibGit2.isdirty(LibGit2.GitRepo(project.path))
            cmd_error("package repository is dirty, please commit or stash changes.")
        end

        committed_changes = false
        if version != "current"
            update_version!(project, version)
            commit_toml(project; push=true)
            committed_changes = true
        else
            # make sure we sync with remote
            gitpush(project)
        end

        try
            register(registry, project)
        catch e
            if committed_changes
                reset_last_commit(project; push=true)
                println(" ", LIGHT_GREEN_FG("✔"), "  revert version bump commit:")
            end
        end
    end
    return
end

function useless_animation(auth::Base.Event, summon::Base.Event, interrupted_or_done::Base.Event)
    anim_chars = ["◐","◓","◑","◒"]
    ansi_enablecursor = "\e[?25h"
    ansi_disablecursor = "\e[?25l"
    t = Timer(0; interval=1/20)
    print_lock = ReentrantLock()
    printloop_should_exit = interrupted_or_done.set
    return @async begin
        try
            count = 1
            while !printloop_should_exit
                # (auth.set || summon.set || interrupted_or_done.set) && return
                lock(print_lock) do
                    print(ansi_disablecursor)
                    print("\e[1G  ", CYAN_FG(anim_chars[mod1(count, 4)]))
                    print("    ")
                    if !auth.set
                        print("authenticating...")
                    elseif !summon.set
                        print("summoning JuliaRegistrator...")
                    else
                        printloop_should_exit = true
                    end
                end
                printloop_should_exit = interrupted_or_done.set
                count += 1
                wait(t)
            end
        catch e
            notify(interrupted_or_done)
            lock(print_lock) do
                println("\e[1G  ", RED_FG("❌"), "  fail to register $(project.pkg.name), error msg:")
                println(e.msg)
            end
            rethrow(e)
        finally
            print(ansi_enablecursor)
        end
    end
end

function register(::PRN"General", project::Project)
    auth_done = Base.Event()
    summon_done = Base.Event()
    interrupted_or_done = Base.Event()

    print_task = useless_animation(auth_done, summon_done, interrupted_or_done)

    github_token = read_github_auth()
    auth = GitHub.authenticate(github_token)
    notify(auth_done)

    HEAD = read_head(project.git)
    comment_json = Dict{String, Any}(
        "body" => registrator_msg(project),
    )

    repo = github_repo(project.git)
    if repo === nothing
        cmd_error("not a GitHub repository")
    end

    # TODO: add an waiting animation here
    # anim_chars = ["◐","◓","◑","◒"]
    # println(" ", LIGHT_GREEN_FG("✔"))
    print("\e[1G    summoning JuliaRegistrator...")
    comment = GitHub.create_comment(repo, HEAD, :commit; params=comment_json, auth=auth)
    notify(summon_done)
    notify(interrupted_or_done)
    wait(print_task)
    println("\e[1G ", LIGHT_GREEN_FG("✔"), "  JuliaRegistrator has been summoned, check it in the following URL:")
    println("  ", CYAN_FG(string(comment.html_url)))
    return comment
end

end

"""
release a package.

# Arguments

- `version`: version number you want to release. Can be a specific version, "current" or either of $(ReleaseCmd.VERSION_TOKENS)
- `path`: path to the project you want to release.

# Options

- `-r,--registry <registry name>`: registry you want to register the package.
    If the package has not been registered, ion will try to register
    the package in the General registry. Or the user needs to specify
    the registry to register using this option.

- `-b, --branch <branch name>`: branch you want to register.
"""
@cast function release(version::String="current", path::String=pwd(); registry="", branch="master")
    ReleaseCmd.release(version, path, registry, branch)
    return
end
