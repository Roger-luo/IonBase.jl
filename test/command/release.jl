module TestRelease

using Test
using Pkg
using IonBase
using UUIDs
using IonBase.ReleaseCmd

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

with_test_ion() do
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

        project = ReleaseCmd.Project(pkgdir(IonBase), quiet=true)
        matches = ReleaseCmd.query_project_registry(project)
        @test length(matches) == 1
        @test first(matches).uuid == UUID("23338594-aafe-5451-b93e-139f81909106")
    end
end

end
