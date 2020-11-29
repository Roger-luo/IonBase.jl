module IonBase

using Comonicon

# for precompile
using Pkg
using GitHub

Comonicon.set_brief_length!(120)

# GITHUB_TOKEN is used in github actions
# GITHUB_AUTH is suggested by GitHub.jl
const ENV_GITHUB_TOKEN_NAMES = ["GITHUB_TOKEN", "GITHUB_AUTH"]

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

function templates(xs...)
    if haskey(ENV, "ION_TEMPLATE_PATH")
        return ENV["ION_TEMPLATE_PATH"]
    else
        return dot_ion("templates", xs...)
    end
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

include("config.jl")

# level 1 commands
include("command/install.jl")
include("command/activate.jl")
include("command/pkg.jl")
include("command/create.jl")
include("command/release.jl")
include("command/search.jl")
include("command/clone.jl")

# extensions
include("command/doc.jl")
include("command/plugin.jl")

include("precompile.jl")
_precompile_()

# @main

end
