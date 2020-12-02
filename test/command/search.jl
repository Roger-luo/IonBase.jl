module TestSearch

using Test
using IonBase
using IonBase.SearchCmd

include(joinpath(pkgdir(IonBase), "test", "utils.jl"))

with_test_ion() do
    @testset "search" begin
        @test first(SearchCmd.search_fuzzy_package("Yao"))[3]["name"] == "Yao"
        @test SearchCmd.search_exact_package("Yao")[end]["name"] == "Yao"
        @test SearchCmd.search_exact_package("ASDWXCASDSAS") === nothing
    end
end

end
