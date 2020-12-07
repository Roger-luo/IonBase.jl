module TestCreate

using Test
using IonBase
using PkgTemplates
using IonBase.CreateCmd
using IonBase: templates
using IonBase.CreateCmd: Comonicon, SystemImage

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

@testset "read_template template.toml" begin
    plugins = CreateCmd.read_template(joinpath(pkgdir(IonBase), "test", "template.toml"))

    @test ProjectFile() in plugins
    @test SrcDir(;file=templates("package/src/test_module.jl")) in plugins
    @test Tests(;file=templates("package/test/test_runtests.jl"), project=false) in plugins
    @test Readme(;file=templates("package/test_README.md"), destination = "README.md", inline_badges = false) in plugins
    @test License(; name = "MIT", path=templates("package/licenses/MIT")) in plugins
    @test Git() in plugins
    @test CompatHelper(;file=templates("package/github/workflows/test_CompatHelper.yml")) in plugins
    @test TagBot(;
        file=templates("package/github/workflows/test_TagBot.yml"),
        ssh_password=Secret("abc"),
        changelog = "abc",
        changelog_ignore = [],
        gpg = Secret("abc"),
        gpg_password = Secret("abc"),
        registry="<owner/repo>",
        branches=false,
        dispatch=false,
        dispatch_delay=false,
    ) in plugins
    @test AppVeyor(;file=templates("package/appveyor.yml"), extra_versions=["1.0", "1.5", "nightly"]) in plugins
    @test CirrusCI(;file=templates("package/cirrus.yml"), extra_versions=["1.0", "1.5", "nightly"]) in plugins
    # @test_broken GitHubActions(;file=templates("package/github/workflows/ci.yml"), extra_versions=["1.0", "1.5", "nightly"]) in plugins
    @test GitLabCI(;file=templates("package/gitlab-ci.yml"), extra_versions=["1.0", "1.5"]) in plugins
    # @test_broken TravisCI(;file=templates("package/travis.yml"), extra_versions=["1.0", "1.5", "nightly"]) in plugins
    @test Codecov(;file=templates("package/.codecov.yml")) in plugins
    @test Coveralls(;file=templates("package/.coveralls.yml")) in plugins
    @test Documenter(;
        make_jl=templates("package/docs/make.jl"),
        index_md=templates("package/docs/src/index.md"),
        logo=Logo("test_light_logo", "test_dark_logo")
    ) in plugins
    @test Citation(;file=templates("package/CITATION.bib")) in plugins
    @test BlueStyleBadge() in plugins
    @test ColPracBadge() in plugins
    @test Comonicon(;name="test", completion=true, quiet=true, compile="min", optimize=2) in plugins
    @test SystemImage() in plugins
end

@testset "read_template basic.toml" begin
    plugins = CreateCmd.read_template(joinpath(pkgdir(IonBase), "templates", "basic.toml"))
    @test !CompatHelper in plugins
    @test !TagBot in plugins
end

CreateCmd.copy_templates(joinpath(pkgdir(IonBase), "test", ".ion", "templates"))

with_test_ion() do
    IonBase.create(joinpath(test_dir, "Basic"); user="abc", force=true)
    IonBase.create(joinpath(test_dir, "Academic"); user= "abc", template = "academic", force=true)
    IonBase.create(joinpath(test_dir, "Package"); user= "abc", template = "package", force=true)
    IonBase.create(joinpath(test_dir, "Comonicon"); user= "abc", template = "comonicon", force=true)
    IonBase.create(joinpath(test_dir, "ComoniconSysImg"); user= "abc", template = "comonicon-sysimg", force=true)
end

end
