using Test
using IonBase

@testset "command/install" begin
    include("command/install.jl")
end

@testset "command/activate" begin
    include("command/activate.jl")
end

@testset "command/create" begin
    include("command/create.jl")
end

@testset "command/release" begin
    include("command/release.jl")
end

@testset "command/search" begin
    include("command/search.jl")
end

@testset "command/pkg" begin
    include("command/pkg.jl")
end

rm(test_ion_dir; force=true, recursive=true)
