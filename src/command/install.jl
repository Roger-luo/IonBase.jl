module InstallCmd

using JSON
using ProgressMeter
using Crayons.Box
using Pkg.BinaryPlatforms
using Comonicon.Tools: prompt, cmd_error
using SHA: sha256
using Downloads: download
using ..IonBase: dot_ion
using ..Options

# NOTE:
# when the user tries to install a certain julia version, it is very possible
# that the user wants to use it, so we create a symlink to julia by default
function install(target::String, version::String, activate::Bool=true, yes::Bool=false, cache::Bool=false)
    if target == "julia"
        install_julia(version, activate, yes, cache)
    else
        cmd_error("unkown target: $target")
    end
end

function install_julia(version_string::String="stable", activate::Bool=true, yes::Bool=false, cache::Bool=false)
    toml = Options.read()

    if Options.find_julia_bin(version_string, toml) !== nothing
        # TODO: update Comonicon to change the default answer to no
        if !prompt("$(CYAN_FG("julia-", version_string)) exists, do you want to install again?", yes)
            return
        end
    end

    version, file = download_julia(version_string, cache)
    julia_bin = if Sys.islinux()
        install_julia_linux(version, file)
    elseif Sys.isapple()
        install_julia_mac(version, file)
    elseif Sys.iswindows()
        install_julia_win(version, file)
    else
        cmd_error("unsupported system")
    end

    # successful installed update meta
    if version_string == "stable"
        toml.julia.stable = version
    end

    bin = dot_ion("bin")

    if activate
        toml.julia.active = julia_bin
        create_symlink(julia_bin, "julia", bin)
    end

    if version isa VersionNumber
        julia_minor = "julia-$(version.major).$(version.minor)"
        for each in readdir(bin)
            if startswith(each, julia_minor)
                @info "clean up old patch version: $(CYAN_FG(each))"
                rm(each; force=true)
            end
        end

        # allocate a list so we can delete the keys
        @info "updating $(CYAN_FG("ion.toml"))"
        for key in collect(keys(toml.julia.versions))
            if (key.major == version.major) && (key.minor == version.minor)
                delete!(toml.julia.versions, key)
            end
        end
    
        create_symlink(julia_bin, "julia-$(version.major).$(version.minor)", bin)
        toml.julia.versions[version] = julia_bin
    else # nightly
        # we create two link: julia-nightly and julia-latest
        create_symlink(julia_bin, "julia-latest", bin)
        toml.julia.nightly = julia_bin
    end

    create_symlink(julia_bin, "julia-$version", bin)
    Options.dump(toml)

    if !cache
        # NOTE: installation won't be very frequently
        # so we just rm tarballs intermediately by default
        rm(file; force=true)
    end
    return julia_bin
end

function _triplet()
    if Sys.islinux()
        BinaryPlatforms.triplet(Linux(Sys.ARCH))
    elseif Sys.isapple()
        BinaryPlatforms.triplet(MacOS(Sys.ARCH))
    elseif Sys.iswindows()
        BinaryPlatforms.triplet(Windows(Sys.ARCH))
    else
        cmd_error("unsupported system")
    end
end

function download_julia_version_json()
    io = IOBuffer()
    download("https://julialang-s3.julialang.org/bin/versions.json", io)
    raw = JSON.parse(String(take!(io)))
    version_info = Dict{VersionNumber, Any}()
    for (k, v) in raw
        version_info[VersionNumber(k)] = v
    end
    return version_info
end

function find_julia_stable(version_info::Dict{VersionNumber, Any}=download_julia_version_json())
    stable = v"0.0.0"
    for (v, info) in version_info
        if stable < v && info["stable"]
            stable = v
        end
    end

    return query_julia_downloads(stable, version_info)
end

function query_julia_downloads(version_string::String, version_info = download_julia_version_json())
    version = Options.find_version(version_string, keys(version_info))
    version === nothing && cmd_error("cannot find version: $version_string")
    return query_julia_downloads(version::VersionNumber, version_info)
end

function query_julia_downloads(version::VersionNumber, version_info = download_julia_version_json())
    for file in version_info[version]["files"]
        if _triplet() == file["triplet"]
            return version, file["sha256"], file["url"]
        end
    end
    cmd_error("cannot find julia binary for this platform")
end

function find_julia_installer_info(version_string::String)
    if version_string == "stable"
        return find_julia_stable()
    elseif version_string == "latest" || version_string == "nightly"
        return find_nightly()
    else
        return query_julia_downloads(version_string)
    end
end

function find_nightly()
    if Sys.ARCH == :x86_64
        arch = 64
        platform = "x64"
    elseif Sys.ARCH == :i686
        arch = 32
        platform = "x86"
    elseif Sys.ARCH == :aarch64
        arch = 64
        platform = "aarch64"
    end

    if Sys.isapple()
        sys = "mac"
        installer = string("mac", arch, ".dmg")
    elseif Sys.islinux()
        sys = "linux"
        if name == "aarch64"
            installer = "linuxaarch64.tar.gz"
        else
            installer = string("linux", arch, ".tar.gz")
        end
    elseif Sys.iswindows()
        sys = "winnt"
        installer = string("win", arch, ".exe")
    end

    url = "https://julialangnightlies-s3.julialang.org/bin/$sys/$platform/julia-latest-$installer"
    return "nightly", nothing, url
end

"""
returns `VersionNumber` or "nightly"
"""
function download_julia(version::String="stable", cache::Bool=false)
    version, sha, url = find_julia_installer_info(version)

    if cache
        ispath(dot_ion("cache")) || mkpath(dot_ion("cache"))
        file = joinpath(dot_ion("cache"), basename(url))
    else
        file = joinpath(tempdir(), basename(url))
    end

    @info "downloading from $url"
    p = Progress(0, 0.1, "julia-$version  ")

    function progress(total, now)
        p.n = total
        if now <= total
            update!(p, now)
        end
        return
    end

    if cache && isfile(file) && validate_julia_download(sha, file)
        @info "julia installer is cached, using existing installer"
        return version, file
    end

    file = download(url, file; progress=progress)
    if validate_julia_download(sha, file)
        @info "checksum: $(CYAN_FG("true"))"
    else
        cmd_error("download is not complete, please try again")
    end
    return version, file
end

# do not validate nightly downloads
validate_julia_download(::Nothing, ::String) = true

function validate_julia_download(sha::String, file::String)
    SHA = open(file) do io
        bytes2hex(sha256(io))
    end

    return SHA == sha
end

function withdmg(f, file::String, mountpoint::String = splitext(basename(file))[1]; maxtry::Int = 5)
    @info "mounting $mountpoint"
    cmd = ignorestatus(`hdiutil attach $file -quiet -mount required -mountpoint $mountpoint`)
    code = 1
    for _ in 1:maxtry
        code = run(cmd).exitcode
        if code == 0
            break
        end
    end
    code == 0 || cmd_error("unable to mount $file")

    ret = f(mountpoint)
    @info "umounting $mountpoint"
    run(`umount $mountpoint`)
    return ret
end

function withtar(f, file::String, mountpoint::String = mktempdir())
    @info "extracting tar $file"
    run(`tar -zxf $file -C $mountpoint`)
    ret = f(mountpoint)
    @info "removing $mountpoint"
    rm(mountpoint; force=true, recursive=true)
    return ret
end

function default_install_dir()
    install_dir = dot_ion("packages")
    if !ispath(install_dir)
        mkpath(install_dir)
    end
    return install_dir
end

function install_julia_linux(version, file::String, install_dir=default_install_dir())
    postfix = version == "nightly" ? version : "$(version.major).$(version.minor)"
    install_path = joinpath(install_dir, "julia-$postfix")
    julia_bin = joinpath(install_path, "bin", "julia")

    if ispath(install_path)
        @info "removing old path: $install_path"
        rm(install_path; force=true, recursive=true)
    end

    withtar(file) do mountpoint
        src = mountpoint
        @info "copying new julia files from $src"
        cp(src, install_path; force=true, follow_symlinks=true)
    end
    return julia_bin
end

function install_julia_mac(version, file::String, install_dir=default_install_dir())
    return withdmg(file) do mountpoint
        dirs = readdir(mountpoint)
        idx = findfirst(startswith("Julia"), dirs)
        idx !== nothing || cmd_error("julia installer does not contain julia binary")
        julia_dir = dirs[idx]
        install_path = joinpath(install_dir, julia_dir)
        julia_bin = "$install_path/Contents/Resources/julia/bin/julia"

        if ispath(install_path)
            @info "removing old path: $(CYAN_FG(install_path))"
            rm(install_path; force=true, recursive=true)
        end

        src = joinpath(mountpoint, julia_dir)
        @info "copying new julia files from $(CYAN_FG(src))"
        cp(src, install_path; force=true, follow_symlinks=true)
        return julia_bin
    end
end

# NOTE: we don't use joinpath(homedir(), .local), since we prefer to allow users to
# remove all effects that ion creates by simply `rm -rf .ion`
# this also makes testing easier, since we can define where .ion is
function create_symlink(src::String, name::String, bin=dot_ion("bin"))
    if !ispath(bin)
        mkpath(bin)
    end

    link = joinpath(bin, name)
    if ispath(link) || islink(link)
        @info "$(CYAN_FG(link)) exists, removing..."
        rm(link; force=true)
    end
    @info "creating symlink: $(CYAN_FG(link))"
    symlink(src, link)
    return
end

function install_julia_win(version, file::String)
    cmd_error("not implemented")
end

end # InstallCmd

# TODO: use traits to implement this so we can make it extensible

"""
install a given target. Currently only supports "julia",

# Arguments

- `target`: install given target, currently only supports `julia`.

# Options

- `-v, --version=<version/stable/nightly>`: version info, can be version number or `stable`/`nightly`.

# Flags

- `-y, --yes`: always choose yes.
- `--cache`: cache downloads in `.ion/cache`.
- `--no-activate`: do not activate the `julia` installation.
"""
@cast function install(target::String; version::String="stable", no_activate::Bool=false, yes::Bool=false, cache::Bool=false)
    try
        InstallCmd.install(target, version, !no_activate, yes, cache)
    catch e
        if (e isa InterruptException) || (e isa TaskFailedException && e.task.result isa InterruptException)
            print("canceled by user")
            return
        else
            rethrow(e)
        end
    end    
    return
end
