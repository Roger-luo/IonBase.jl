"""
default template.
"""
const DEFAULT_TEMPLATE = Ref{String}("default")

"""
default user name.
"""
const DEFAULT_USERNAME = Ref{String}("")

function set_default_template(name::String="default")
    DEFAULT_TEMPLATE[] = name
    return
end

function set_default_username(name::String="")
    DEFAULT_USERNAME[] = name
    return
end

struct PDTN{name} end

PDTN(name::String) = PDTN{Symbol(name)}()

macro PDTN_str(name::String)
    return PDTN{Symbol(name)}
end

Base.show(io::IO, ::PDTN{template}) where {template} = print(io, "Pre-defined Template Name Type ", string(template))

"""
create a project or package.

# Arguments

- `path`: path of the project you want to create

# Options

- `--user <name>`: your GitHub user name for this package.
- `--template <template name>`: template name.

# Flags

- `-i, --interactive`: enable to start interactive configuration interface.
"""
@cast function create(path; user=DEFAULT_USERNAME[], interactive::Bool=false, template=DEFAULT_TEMPLATE[])
    if !isabspath(path)
        fullpath = joinpath(pwd(), path)
    else
        fullpath = path
    end

    if ispath(fullpath)
        error("$path exists, remove it or use a new path")
    end

    # if not specified, check if user.name is set in git
    if isempty(user)
        user = readchomp(`git config user.name`)
    end
    # TODO: use .ionrc to save user configuration
    # and reuse it next time

    t = create_template(PDTN(template), dirname(fullpath), user, interactive)
    t(basename(fullpath))
    return
end
