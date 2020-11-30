using PkgTemplates

function PkgTemplates.default_file(paths::AbstractString...)
    return templates("package", paths...)
end
