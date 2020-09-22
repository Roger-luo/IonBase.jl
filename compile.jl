using SnoopCompile, Pkg
project = Pkg.project().path
### Log the compiles
# This only needs to be run once (to generate "/tmp/comonicon_compiles.log")

SnoopCompile.@snoopc ["--project=$project"] "/tmp/ion_compiles.log" begin
    using IonBase, Comonicon
    include(Comonicon.PATH.project(IonBase, "test", "runtests.jl"))
    IonBase.search("Yao")

    cd(Comonicon.PATH.project(IonBase, "test")) do
        IonBase.
    end
end

### Parse the compiles and generate precompilation scripts
# This can be run repeatedly to tweak the scripts

data = SnoopCompile.read("/tmp/ion_compiles.log")

pc = SnoopCompile.parcel(reverse!(data[2]))
SnoopCompile.write("/tmp/precompile", pc)
