using SnoopCompile, Pkg
project_path = dirname(dirname(@__FILE__))
rm(joinpath(project_path, "src", "precompile.jl"); force=true)
open(joinpath(project_path, "src", "precompile.jl"), "w+") do io
    println(io, "_precompile_() = nothing")
end

### Log the compiles
# This only needs to be run once (to generate "/tmp/comonicon_compiles.log")

SnoopCompile.@snoopc ["--project=$(project_path)"] "/tmp/ion_compiles.log" begin
    using IonBase, Comonicon

    cd(tempdir()) do
        rm("Foo"; recursive=true, force=true)
        IonBase.create("Foo"; user="xyz")
        rm("Foo"; recursive=true, force=true)
        IonBase.create("Foo"; user="xyz", template="comonicon")
        rm("Foo"; recursive=true, force=true)
    end

    include(Comonicon.PATH.project(IonBase, "test", "runtests.jl"))
    IonBase.search("Yao")
    IonBase.Doc.build(Comonicon.PATH.project(IonBase))
end

### Parse the compiles and generate precompilation scripts
# This can be run repeatedly to tweak the scripts

data = SnoopCompile.read("/tmp/ion_compiles.log")
pc = SnoopCompile.parcel(reverse!(data[2]))

open(joinpath(project_path, "src", "precompile.jl"), "w") do io
    if any(str->occursin("__lookup", str), pc[:IonBase])
        println(io, lookup_kwbody_str)
    end
    println(io, "function _precompile_()")
    println(io, "    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing")
    for ln in sort(pc[:IonBase])
        println(io, "    ", ln)
    end
    println(io, "end")
end
