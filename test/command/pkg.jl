module PkgCmd

using IonBase

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

with_test_ion() do
    cd(joinpath(test_dir, "Basic")) do
        IonBase.add("OhMyREPL")
        IonBase.rm("OhMyREPL")
        IonBase.instantiate()
        IonBase.status()
    end
end

end
