
const YesDeploy = ["TravisCI", "GitHubActions", "GitLabCI"]
const GitHubPagesStyle = ["TravisCI", "GitHubActions"]

"""
    Logo(; light=nothing, dark=nothing)

Logo information for documentation.

## Keyword Arguments
- `light::AbstractString`: Path to a logo file for the light (default) theme.
- `dark::AbstractString`: Path to a logo file for the dark theme.
"""
@option struct Logo
    light::Union{String, Nothing} = nothing
    dark::Union{String, Nothing} = nothing
end

"""
    Documenter(;
        depoly="",
        make_jl=".ion/templates/package/docs/make.jl",
        index_md=".ion/templates/package/docs/src/index.md",
        assets=String[],
        logo=Logo(),
        canonical_url=make_canonical(T),
        makedocs_kwargs=Dict{Symbol, Any}(),
    )

Sets up documentation generation via [Documenter.jl](https://github.com/JuliaDocs/Documenter.jl).
Documentation deployment depends on `T`, where `T` is some supported CI plugin,
or `Nothing` to only support local documentation builds.

## Supported Type Parameters
- `GitHubActions`: Deploys documentation to [GitHub Pages](https://pages.github.com)
  with the help of [`GitHubActions`](@ref).
- `TravisCI`: Deploys documentation to [GitHub Pages](https://pages.github.com)
  with the help of [`TravisCI`](@ref).
- `GitLabCI`: Deploys documentation to [GitLab Pages](https://pages.gitlab.com)
  with the help of [`GitLabCI`](@ref).
- `NoDeploy` (default): Does not set up documentation deployment.

## Keyword Arguments
- `make_jl::AbstractString`: Template file for `make.jl`.
- `index_md::AbstractString`: Template file for `index.md`.
- `assets::Vector{<:AbstractString}`: Extra assets for the generated site.
- `logo::Logo`: A [`Logo`](@ref) containing documentation logo information.
- `canonical_url::Union{Function, Nothing}`: A function to generate the site's canonical URL.
  The default value will compute GitHub Pages and GitLab Pages URLs
  for [`TravisCI`](@ref) and [`GitLabCI`](@ref), respectively.
  If set to `nothing`, no canonical URL is set.
- `makedocs_kwargs::Dict{Symbol}`: Extra keyword arguments to be inserted into `makedocs`.
- `devbranch::Union{AbstractString, Nothing}`: Branch that will trigger docs deployment.

!!! note
    If deploying documentation with Travis CI, don't forget to complete
    [the required configuration](https://juliadocs.github.io/Documenter.jl/stable/man/hosting/#SSH-Deploy-Keys-1).
"""
@plugin struct Documenter <: Plugin
    depoly::String = "" # TravisCI, GitHubActions, GitLabCI
    assets::Vector{String} = String[]
    logo::Logo = Logo()
    makedocs_kwargs::Dict{Symbol} = Dict{Symbol, Any}()
    canonical_url::Bool = !isempty(depoly)
    make_jl::String = default_file("docs", "make.jl")
    index_md::String = default_file("docs", "src", "index.md")
    devbranch::Union{String, Nothing} = nothing
end

gitignore(::Documenter) = ["/docs/build/"]
priority(::Documenter, ::Function) = DEFAULT_PRIORITY - 1  # We need SrcDir to go first.

function badges(p::Documenter)
    isempty(p.depoly) && return Badge[]
    
    if p.depoly in GitHubPagesStyle
        return [
            Badge(
                "Stable",
                "https://img.shields.io/badge/docs-stable-blue.svg",
                "https://{{{USER}}}.github.io/{{{PKG}}}.jl/stable",
            ),
            Badge(
                "Dev",
                "https://img.shields.io/badge/docs-dev-blue.svg",
                "https://{{{USER}}}.github.io/{{{PKG}}}.jl/dev",
            ),
        ]
    end

    if p.depoly == "GitLabCI"
        return Badge(
            "Dev",
            "https://img.shields.io/badge/docs-dev-blue.svg",
            # TODO: Support custom domain here.
            "https://{{{USER}}}.gitlab.io/{{{PKG}}}.jl/dev",
        )
    end
end

function view(p::Documenter, t::PackagePlan, pkg::AbstractString)
    base = Dict(
        "ASSETS" => map(basename, p.assets),
        "AUTHORS" => join(t.authors, ", "),
        "CANONICAL" => canonical_url(p, t, pkg),
        "HAS_ASSETS" => !isempty(p.assets),
        "MAKEDOCS_KWARGS" => map(((k, v),) -> k => repr(v), collect(p.makedocs_kwargs)),
        "PKG" => pkg,
        "REPO" => "$(t.host)/$(t.user)/$pkg.jl",
        "USER" => t.user,
        "BRANCH" => p.devbranch === nothing ? default_branch(t) : p.devbranch,
    )


    if p.depoly in GitHubPagesStyle
        base["HAS_DEPLOY"] = true
    end
    
    return base
end

function canonical_url(p::Documenter, t::PackagePlan, pkg::String)
    p.canonical_url || return
    if p.depoly in GitHubPagesStyle
        return github_pages_url(t, pkg)
    elseif p.depoly == "GitLabCI"
        return gitlab_pages_url(t, pkg)
    else
        return
    end
end

function validate(p::Documenter, t::PackagePlan)
    if isempty(p.depoly)
        foreach(p.assets) do a
            isfile(a) || throw(ArgumentError("Asset file $a does not exist"))
        end
        foreach((:light, :dark)) do k
            logo = getfield(p.logo, k)
            if logo !== nothing && !isfile(logo)
                throw(ArgumentError("Logo file $logo does not exist"))
            end
        end
    end

    invoke(validate, Tuple{Documenter, PackagePlan}, p, t)
    if !hasplugin(t, T)
        name = nameof(T)
        s = "Documenter: The $name plugin must be included for docs deployment to be set up"
        throw(ArgumentError(s))
    end
end

function hook(p::Documenter, t::PackagePlan, pkg_dir::AbstractString)
    pkg = basename(pkg_dir)
    docs_dir = joinpath(pkg_dir, "docs")

    # Generate files.
    make = render_file(p.make_jl, combined_view(p, t, pkg), tags(p))
    index = render_file(p.index_md, combined_view(p, t, pkg), tags(p))
    gen_file(joinpath(docs_dir, "make.jl"), make)
    gen_file(joinpath(docs_dir, "src", "index.md"), index)

    # Copy over any assets.
    assets_dir = joinpath(docs_dir, "src", "assets")
    mkpath(assets_dir)
    foreach(a -> cp(a, joinpath(assets_dir, basename(a))), p.assets)
    foreach((:light => "logo", :dark => "logo-dark")) do (k, f)
        logo = getfield(p.logo, k)
        if logo !== nothing
            _, ext = splitext(logo)
            cp(logo, joinpath(assets_dir, "$f$ext"))
        end
    end
    isempty(readdir(assets_dir)) && rm(assets_dir)

    # Create the documentation project.
    d = Dict{String, Any}(
        "deps" => Dict{String, Any}(
            "Documenter" => "e30172f5-a6a5-5a46-863b-614d45cd2de4"
        )
    )

    cd(docs_dir) do
        open("Project.toml", "w") do io
            TOML.print(io, d)        
        end

        PkgCmd.withproject("Pkg.develop(PackageSpec(; path=\"..\"))", false, "dev $(t.name)")
    end
end

github_pages_url(t::PackagePlan, pkg::AbstractString) = "https://$(t.user).github.io/$pkg.jl"
gitlab_pages_url(t::PackagePlan, pkg::AbstractString) = "https://$(t.user).gitlab.io/$pkg.jl"

needs_username(::Documenter) = true

function customizable(::Type{<:Documenter})
    return (:canonical_url => NotCustomizable, :makedocs_kwargs => NotCustomizable)
end

function interactive(::Type{Documenter})
    styles = [NoDeploy, TravisCI, GitLabCI, GitHubActions]
    menu = RadioMenu(map(string, styles); pagesize=length(styles))
    println("Documenter deploy style:")
    idx = request(menu)
    return interactive(Documenter{styles[idx]})
end

function prompt(::Type{<:Documenter}, ::Type{Logo}, ::Val{:logo})
    light = Base.prompt("Enter value for 'logo.light' (String, default=nothing)")
    dark = Base.prompt("Enter value for 'logo.dark' (String, default=nothing)")
    return Logo(; light=light, dark=dark)
end
