module CloneCmd

using TOML
using GitHub
using ..IonBase: read_github_auth
using ..SearchCmd: search_exact_package, fetch_repo_from_url
using Comonicon.Tools: prompt

function clone_url(url::String)
    if endswith(url, "jl.git")
        _clone(url, basename(url)[1:end-7])
    else
        _clone(url, basename(url))
    end
end

function clone_package(package::String)
    info = search_exact_package(package)
    isnothing(info) && error("cannot find $package in registries")
    uuid, reg, pkginfo = info
    pkg_toml = TOML.parsefile(joinpath(reg.path, pkginfo["path"], "Package.toml"))
    _clone(pkg_toml["repo"], pkg_toml["name"])
end

function _clone(url::String, to::String)
    username = readchomp(`git config user.name`)
    auth = GitHub.authenticate(read_github_auth())
    rp = fetch_repo_from_url(url; auth=auth)

    local has_access
    try
        has_access = iscollaborator(rp, username; auth=auth)
    catch e
        has_access = false
    end

    if has_access
        git_clone(url, to)
    elseif prompt("do not have access to $url, fork?")
        @info "fork upstream repo: $rp"
        owned_repo = fork_repo(rp, auth)
        git_clone(owned_repo.clone_url.uri, to)
        @info "setting upstream to $url"
        set_upstream(url, to)
    end
end

function fork_repo(repo, auth)
    return create_fork(repo; auth=auth)
end

function set_upstream(url::String, to::String)
    cd(joinpath(pwd(), to)) do
        run(`git remote add upstream $url`)
        run(`git fetch upstream`)
        run(`git branch --set-upstream-to=upstream/master`)
    end
end

function git_clone(url, to)
    run(`git clone $url $to`)
end


# Copied from IsURL.jl
# Source: https://github.com/sindresorhus/is-absolute-url (MIT license)
const windowsregex = r"^[a-zA-Z]:[\\]"
const urlregex = r"^[a-zA-Z][a-zA-Z\d+\-.]*:"

"""
    isurl(str)
Checks if the given string is an absolute URL.
# Examples
```julia-repl
julia> isurl("https://julialang.org")
true
julia> isurl("mailto:someone@example.com")
true
julia> isurl("/foo/bar")
false
```
"""
function isurl(str::AbstractString)
    return !occursin(windowsregex, str) && occursin(urlregex, str)
end

function isgithub(url::AbstractString)
    if startswith(url, "http") && startswith(split(url, "//")[2], "github.com")
        return true
    else
        return false
    end
end

function clone(url_or_package::String)
    if isurl(url_or_package)
        clone_url(url_or_package)
    else
        clone_package(url_or_package)
    end
    return
end

end

"""
clone a package or url and setup the local repo. If the current local
git user do not have push access to remote github repo, it will fork
this repo then clone the repo and set the input url as upstream.

# Arguments

- `url_or_package`: name of the package or url.
"""
@cast function clone(url_or_package::String)
    CloneCmd.clone(url_or_package)
end
