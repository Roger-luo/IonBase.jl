module TestCreate

using Test
using IonBase
using IonBase.Templates
using Configurations

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

with_test_ion() do
    IonBase.copy_templates()
end

with_test_ion() do
    IonBase.create(joinpath(test_dir, "Basic"); user="abc", force=true)
    IonBase.create(joinpath(test_dir, "Academic"); user= "abc", template = "academic", force=true)
    IonBase.create(joinpath(test_dir, "Package"); user= "abc", template = "package", force=true)
    IonBase.create(joinpath(test_dir, "Comonicon"); user= "abc", template = "comonicon", force=true)
    IonBase.create(joinpath(test_dir, "ComoniconSysImg"); user= "abc", template = "comonicon-sysimg", force=true)
end

end
