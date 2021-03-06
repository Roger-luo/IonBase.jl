function _precompile_()
    ccall(:jl_generating_output, Cint, ()) == 1 || return nothing
    precompile(Tuple{IonBase.SearchCmd.var"#fetch_repo##kw", NamedTuple{(:auth,), Tuple{GitHub.OAuth2}}, typeof(IonBase.SearchCmd.fetch_repo), Pkg.Types.RegistrySpec, Base.Dict{String, Any}})
    precompile(Tuple{IonBase.SearchCmd.var"#fetch_repo_from_url##kw", NamedTuple{(:auth,), Tuple{GitHub.OAuth2}}, typeof(IonBase.SearchCmd.fetch_repo_from_url), String})
    precompile(Tuple{typeof(IonBase.CreateCmd.copy_templates), String})
    precompile(Tuple{typeof(IonBase.CreateCmd.read_template), String})
    precompile(Tuple{typeof(IonBase.Doc.build), String})
    precompile(Tuple{typeof(IonBase.InstallCmd.find_julia_installer_info), String})
    precompile(Tuple{typeof(IonBase.ReleaseCmd.is_version_number), String})
    precompile(Tuple{typeof(IonBase.ReleaseCmd.update_version!), IonBase.ReleaseCmd.Project, String})
    precompile(Tuple{typeof(IonBase.SearchCmd.print_stars), Base.TTY, GitHub.Repo})
    precompile(Tuple{typeof(IonBase.SearchCmd.search_exact_package), String})
    precompile(Tuple{typeof(IonBase.SearchCmd.search_fuzzy_package), String})
    precompile(Tuple{typeof(IonBase.dot_ion), String, String})
    precompile(Tuple{typeof(IonBase.search), String})
    precompile(Tuple{typeof(IonBase.templates), String, Int})
    precompile(Tuple{typeof(IonBase.templates), String, String})
end
