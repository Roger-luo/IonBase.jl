const test_dir = joinpath(pkgdir(IonBase), "test")
const test_ion_dir = joinpath(test_dir, ".ion")
const test_template = joinpath(test_dir, "acdemic.toml")

function with_test_ion(f)
    withenv(f, "DOT_ION_PATH"=>test_ion_dir)
end
