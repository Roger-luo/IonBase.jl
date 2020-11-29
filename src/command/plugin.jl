"plugin tools"
module Plugin

using ..Options
using Comonicon
using Pkg

"""
add an ion plugin.

# Arguments

- `name`: plugin name, can be url or a package name.
"""
@cast function add(name::String)
    Pkg.add(name)
    ion = Options.read()::Ion
    push!(ion.plugins, name)
    Options.dump(ion)
    return
end

@cast function rm(name::String)
    Pkg.rm(name)
    ion = Options.read()::Ion
    idx = findfirst(isequal(name), ion.plugins)
    deleteat!(ion.plugins, idx)
    Options.dump(ion)
    return
end

end

@cast Plugin
