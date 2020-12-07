using IonBase
using IonBase.Templates
using Configurations

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))
with_test_ion() do
    IonBase.copy_templates()
end

with_test_ion() do
    IonBase.create("Foo"; user="me", template="package", authors="A,B")
end

t = Template("basic", [
    CompatHelper(),
    Git(),
    License(),
    ProjectFile(),
    Readme(),
    SrcDir(),
    TagBot(),
    Tests(),
])

toml("templates/basic.toml", t)

t = Template("academic", [
    CompatHelper(),
    Git(),
    License(),
    ProjectFile(),
    Readme(),
    SrcDir(),
    TagBot(),
    Tests(),
    Citation(),
])

toml("templates/academic.toml", t)

t = Template("package", [
    CompatHelper(),
    Git(),
    License(),
    ProjectFile(),
    Readme(),
    SrcDir(),
    TagBot(),
    Tests(),
    GitHubActions(),
    Codecov(),
    Documenter(;depoly="GitHubActions"),
])

toml("templates/package.toml", t)

t = Template("comonicon", [
    CompatHelper(),
    Git(),
    License(),
    ProjectFile(),
    Readme(),
    SrcDir(),
    TagBot(),
    Tests(),
    GitHubActions(),
    Codecov(),
    Documenter(;depoly="GitHubActions"),
    Comonicon(),
])

toml("templates/comonicon.toml", t)

t = Template("comonicon-sysimg", [
    CompatHelper(),
    Git(),
    License(),
    ProjectFile(),
    Readme(),
    SrcDir(),
    TagBot(),
    Tests(),
    GitHubActions(),
    Codecov(),
    Documenter(;depoly="GitHubActions"),
    Comonicon(),
    SystemImage(),
])

toml("templates/comonicon-sysimg.toml", t)
