@plugin struct SystemImage <: Plugin
    path::String="deps/lib"
    incremental::Bool=false
    filter_stdlibs::Bool=true
    cpu_target::String="x86-64"
end

@plugin struct Comonicon <: Plugin
    name::Union{Nothing, String} = nothing
    # install
    completion::Bool=true
    quiet::Bool=false
    compile::Union{Nothing, String} = nothing
    optimize::Int=2
end

customizable(::Type{<:Comonicon}) = [
    :name=>String,
    :completion=>Bool,
    :quiet=>Bool,
    :compile=>String,
    :optimize=>Int
]

customizable(::Type{<:SystemImage}) = [
    :path=>String,
    :incremental=>Bool,
    :filter_stdlibs=>Bool,
    :cpu_target=>String,
]

# set up deps
function prehook(::Comonicon, ::Template, pkg_dir::AbstractString)
    if !ispath(joinpath(pkg_dir, "deps"))
        mkpath(joinpath(pkg_dir, "deps"))
    end
end

# create Comonicon.toml and build.jl
function hook(p::Comonicon, t::Template, pkg_dir::AbstractString)
    suffix = ".jl"
    sysimg = nothing
    for each in t.plugins
        if (each isa Git) && (each.jl == false)
            suffix = ""
        end

        if each isa SystemImage
            sysimg = each
        end
    end

    pkg = basename(pkg_dir)
    toml = OrderedDict{String, Any}(
        "name" => isnothing(p.name) ? default_name(pkg) : p.name
    )

    toml["install"] = OrderedDict{String, Any}(
        "completion" => p.completion,
        "quiet" => p.quiet,
        "optimize" => p.optimize,
    )

    if !isnothing(p.compile)
        toml["install"]["compile"] = p.compile
    end

    # system image related files/configs
    if !isnothing(sysimg)
        toml["sysimg"] = OrderedDict(
            "path" => sysimg.path,
            "incremental" => sysimg.incremental,
            "filter_stdlibs" => sysimg.filter_stdlibs,
            "cpu_target" => sysimg.cpu_target,
        )

        toml["download"] = OrderedDict(
            "host" => t.host,
            "user" => t.user,
            "repo" => pkg * suffix,
        )
    end # system image related files/configs

    open(joinpath(pkg_dir, "Comonicon.toml"), "w") do f
        TOML.print(f, toml)
    end

    open(joinpath(pkg_dir, "deps", "build.jl"); append=true) do f
        println(f, "using $pkg; $pkg.comonicon_install()")
    end
end

function hook(p::SystemImage, t::Template, pkg_dir::AbstractString)
    any(x->(x isa Comonicon), t.plugins) || error("SystemImage plugin must be used with Comonicon")
    workflow_dir = joinpath(pkg_dir, ".github", "workflows")
    mkpath(workflow_dir)
    cp(
        joinpath(
            templates("package", "github", "workflows", "sysimg.yml")
        ),
        joinpath(workflow_dir, "sysimg.yml")
    )
end

gitignore(::Comonicon) = ["/deps/build.log"]
gitignore(::SystemImage) = ["/deps/lib", "/deps/precompile.jl"]
needs_username(::Comonicon) = true