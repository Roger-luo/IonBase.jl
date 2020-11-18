using IonBase
using Comonicon.PATH
using Test
using PkgTemplates
using Pkg
using TOML

@testset "create & release" begin

    @test IonBase.is_version_number("0.1.0")
    @test IonBase.is_version_number("v0.1.0")

    @test_throws ErrorException IonBase.create(PATH.project(IonBase, "test", "dummy2"); user="Roger-luo", template="unknown")

    dummy_project = PATH.project(IonBase, "test", "dummy")
    rm(dummy_project, recursive=true, force=true)
    IonBase.create(dummy_project; user="Roger-luo", template="test")
    project = IonBase.Project(dummy_project, quiet=true)
    @test project.pkg.version == v"0.1.0"
    @test project.path == dummy_project

    IonBase.update_version!(project, "0.2.0")
    @test project.pkg.version == v"0.2.0"
    @test Pkg.Types.read_project(joinpath(dummy_project, "Project.toml")).version == v"0.2.0"

    IonBase.update_version!(project, "patch")
    @test project.pkg.version == v"0.2.1"
    @test Pkg.Types.read_project(joinpath(dummy_project, "Project.toml")).version == v"0.2.1"

    IonBase.update_version!(project, "minor")
    @test project.pkg.version == v"0.3.0"
    @test Pkg.Types.read_project(joinpath(dummy_project, "Project.toml")).version == v"0.3.0"

    IonBase.update_version!(project, "major")
    @test project.pkg.version == v"1.0.0"
    @test Pkg.Types.read_project(joinpath(dummy_project, "Project.toml")).version == v"1.0.0"

end

@testset "search" begin
    @test first(IonBase.search_fuzzy_package("Yao"))[3]["name"] == "Yao"
    @test IonBase.search_exact_package("Yao")[end]["name"] == "Yao"
    @test IonBase.search_exact_package("ASDWXCASDSAS") === nothing
end

@testset "template/comonicon" begin
    test_comonicon = PATH.project(IonBase, "test", "Foo")
    dir = dirname(test_comonicon)
    rm(test_comonicon; recursive=true, force=true)

    t = Template(;
            dir=dir,
            user="me",
            plugins=[
                Readme(;
                    file = IonBase.PATH.templates("command", "README.md"),
                    destination="README.md",
                    inline_badges=false
                ),
                Git(;name="me", email="a@b.c"),
                IonBase.ComoniconFiles(),
            ]
        )

    t(basename(test_comonicon))
    comonicon_toml = joinpath(test_comonicon, "Comonicon.toml")
    @test isfile(comonicon_toml)
    toml = TOML.parsefile(comonicon_toml)
    @test toml["name"] == "foo"
    @test toml["install"]["optimize"] == 2
    @test toml["install"]["quiet"] == false
    @test toml["install"]["completion"] == true
    @test isfile(joinpath(test_comonicon, "deps", "build.jl"))
end

@testset "template/comonicon-sysimg" begin
    test_comonicon = PATH.project(IonBase, "test", "Foo")
    dir = dirname(test_comonicon)
    rm(test_comonicon; recursive=true, force=true)

    t = Template(;
        dir=dir,
        user="me",
        plugins=[
            Readme(;
                file = IonBase.PATH.templates("command", "README.md"),
                destination="README.md",
                inline_badges=false
            ),
            Git(;name="me", email="a@b.c"),
            IonBase.ComoniconFiles(),
            IonBase.SystemImage(),
        ]
    )

    t(basename(test_comonicon))
    comonicon_toml = joinpath(test_comonicon, "Comonicon.toml")
    @test isfile(comonicon_toml)
    toml = TOML.parsefile(comonicon_toml)
    @test toml["name"] == "foo"
    @test toml["sysimg"]["filter_stdlibs"] == true
    @test toml["sysimg"]["cpu_target"] == "x86-64"
    @test toml["sysimg"]["incremental"] == false
    @test toml["sysimg"]["path"] == "deps/lib"

    @test toml["download"]["repo"] == "Foo.jl"
    @test toml["download"]["host"] == "github.com"
    @test toml["download"]["user"] == "me"
end
