module PkgCmd

using IonBase

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

cd(joinpath(test_dir, "Foo")) do
    IonBase.add("OhMyREPL")
    IonBase.rm("OhMyREPL")
    IonBase.instantiate()
    IonBase.status()
end

end
