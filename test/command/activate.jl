module TestActivate

using Test
using IonBase
using IonBase.ActivateCmd

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

function read_julia_version(julia::String)
    VersionNumber(readchomp(`$(IonBase.dot_ion("bin", julia)) --version`)[15:end])
end

@testset "test real installation" begin
    with_test_ion() do
        IonBase.activate("1.5.3")
        @test read_julia_version("julia") == v"1.5.3"
        IonBase.activate("stable")
        @test read_julia_version("julia") >= v"1.5.3"
        IonBase.activate("nightly")
        @test read_julia_version("julia") >= v"1.6-DEV"
    end
end

end # TestActivate