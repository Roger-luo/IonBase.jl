module ActivateCmd

using Crayons.Box
using Comonicon.Tools: prompt
using ..Options
using ..InstallCmd: install_julia, create_symlink

function activate(version::String)
    ion = Options.read()
    bin = Options.find_julia_bin(version, ion)
    if bin === nothing
        if prompt("cannot find julia $version, do you want to install?")
            install_julia(version, true)
        end
    else
        @info "activating $(CYAN_FG("julia-", version))"
        create_symlink(bin, "julia")
        ion.julia.active = bin
        Options.dump(ion)
    end
    return
end

end # ActivateCmd

@cast function activate(version::String="stable")
    try
        ActivateCmd.activate(version)
    catch e
        if e isa InterruptException
            print("canceled by user")
            return
        else
            rethrow(e)
        end
    end
end
