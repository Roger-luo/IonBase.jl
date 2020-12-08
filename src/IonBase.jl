module IonBase

using Comonicon
using MatchCore
# for precompile
using Pkg
using GitHub
using Downloads
using Comonicon.Tools: cmd_error

Comonicon.set_brief_length!(120)

# GITHUB_TOKEN is used in github actions
# GITHUB_AUTH is suggested by GitHub.jl
const ENV_GITHUB_TOKEN_NAMES = ["GITHUB_TOKEN", "GITHUB_AUTH"]

# TODO: we might want to change PackageCompiler to set our own
# depot path
function ion_dir()
    if haskey(ENV, "DOT_ION_PATH")
        return ENV["DOT_ION_PATH"]
    elseif Sys.isapple() || Sys.islinux()
        return joinpath(homedir(), ".ion")
    elseif Sys.iswindows()
        return expanduser(raw"~\AppData\Local\Ion")
    end
end

dot_ion(xs...) = joinpath(ion_dir(), xs...)
ca_roots() = dot_ion("cert.pem")

function templates(xs...)
    if haskey(ENV, "ION_TEMPLATE_PATH")
        return ENV["ION_TEMPLATE_PATH"]
    else
        return dot_ion("templates", xs...)
    end
end

function copy_templates(dst::String=templates())
    ispath(dst) || mkpath(dst)
    ion_template_dir = joinpath(pkgdir(IonBase), "templates")
    cp(ion_template_dir, dst; force=true, follow_symlinks=true)
end

function copy_cacert(dst::String=ca_roots())
    # Linux is fine, we just ship julia's ca
    # with Mac build
    if Sys.isapple()
        cp(Downloads.ca_roots_path(), dst; force=true, follow_symlinks=true)
    end
end

function copy_assets()
    copy_templates()
    copy_cacert()
end

ion_toml() = dot_ion("ion.toml")

function init_dot_ion()
    dot_ion_dir = dot_ion()
    if !ispath(dot_ion_dir)
        mkpath(dot_ion_dir)
        return true
    end
    return false
end

function read_github_auth()
    for key in ENV_GITHUB_TOKEN_NAMES
        if haskey(ENV, key)
            return ENV[key]
        end
    end

    buf = Base.getpass("GitHub Access Token (https://github.com/settings/tokens)")
    auth = read(buf, String)
    Base.shred!(buf)
    return auth
end

function gitcmd(path::AbstractString; kw...)
    cmd = ["git", "-C", path]
    for (n,v) in kw
        push!(cmd, "-c")
        push!(cmd, "$n=$v")
    end
    return Cmd(cmd)
end

include("options.jl")
# level 1 commands
include("command/install.jl")
include("command/activate.jl")
include("command/pkg.jl")

# level 2 commands
include("templates/templates.jl")
include("command/search.jl")
include("command/release.jl")
include("command/clone.jl")

# extensions
include("command/doc.jl")
include("command/plugin.jl")

# include("precompile.jl")
# _precompile_()

# "The Ion manager."
# @main

end
