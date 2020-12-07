module TestInstall

using Test
using IonBase
using IonBase.InstallCmd
using IonBase.Options

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

@testset "find_julia_installer_info" begin
    version, _, _ = InstallCmd.find_julia_installer_info("stable")
    @test version <= v"2.0.0"
    version, _, _ = InstallCmd.find_julia_installer_info("nightly")
    @test version == "nightly"
    version, _, _ = InstallCmd.find_julia_installer_info("1.5.3")
    @test version == v"1.5.3"
    version, _, _ = InstallCmd.find_julia_installer_info("1.4")
    @test version == v"1.4.2"
end

@testset "test real installation" begin
    with_test_ion() do
        IonBase.install("julia", "stable";yes=true, cache=true)
        IonBase.install("julia", "nightly"; yes=true, cache=true)
        IonBase.install("julia", "latest"; yes=true, cache=true)
        # make sure 1.5.3 is installed
        # for later testing
        IonBase.install("julia", "1.5.3"; yes=true, cache=true)
        IonBase.install("julia", "1.4.2"; yes=true, cache=true)

        ion = Options.read()
        @test ion.julia.active === ion.julia.versions[v"1.4.2"]
        @test ion.julia.nightly !== nothing
        @test ion.julia.stable === v"1.5.3"
    end
end

end
