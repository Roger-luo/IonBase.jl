module TestRelease

using Test
using Pkg
using IonBase
using IonBase.ReleaseCmd

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

@testset "release" begin

    @test ReleaseCmd.is_version_number("0.1.0")
    @test ReleaseCmd.is_version_number("v0.1.0")

    basic_project = joinpath(test_dir, "Basic")
    project = ReleaseCmd.Project(basic_project, quiet=true)
    @test project.pkg.version == v"0.1.0"
    @test project.path == basic_project

    ReleaseCmd.update_version!(project, "0.2.0")
    @test project.pkg.version == v"0.2.0"
    @test Pkg.Types.read_project(joinpath(basic_project, "Project.toml")).version == v"0.2.0"

    ReleaseCmd.update_version!(project, "patch")
    @test project.pkg.version == v"0.2.1"
    @test Pkg.Types.read_project(joinpath(basic_project, "Project.toml")).version == v"0.2.1"

    ReleaseCmd.update_version!(project, "minor")
    @test project.pkg.version == v"0.3.0"
    @test Pkg.Types.read_project(joinpath(basic_project, "Project.toml")).version == v"0.3.0"

    ReleaseCmd.update_version!(project, "major")
    @test project.pkg.version == v"1.0.0"
    @test Pkg.Types.read_project(joinpath(basic_project, "Project.toml")).version == v"1.0.0"
end

end
