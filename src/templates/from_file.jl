template_plugins(::PDTN) = nothing

function create_template(t::PDTN{name}, dir, user, interactive) where name
    plugins = template_plugins(t)
    if !isnothing(plugins)
        if isempty(user)
            @warn "git host user name not found, please specify " *
                "using --user to enable GitHub related plugins " *
                "or use -i/--interactive to configure interactively"
            return Template(;
                dir=dir,
                interactive=interactive,
                plugins = [plugins..., !Git, !TagBot, !CompatHelper],
            )
        else
            return Template(;
                dir=dir,
                user=user,
                interactive=interactive,
                plugins = plugins,
            )
        end
    else
        template = search_local_template(t)
        isnothing(template) && error("template $(name) not found")
        return template
    end
end

function search_local_template(::PDTN{name}) where name
    template_dir = PATH.dot_ion("templates")
    ispath(template_dir) || return
    template = string(name)
    for dir in readdir(template_dir)
        if dir == template
            error("read/save local template is not supported yet")
            # return read_template(joinpath(template_dir, dir))
        end
    end
    return
end

# function read_template(path)
#     file = joinpath(path, "README.md")
#     plugins = []
#     if isfile(file)
#         push!(plugins, Readme(;file=file))
#     end

#     file = joinpath(path, "Project.toml")
    
# end
