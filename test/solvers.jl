# Similar to JuMP/test/solvers.jl

function try_import(name::Symbol)
    try
        @eval import $name
        return true
    catch e
        return false
    end
end

mos = try_import(:MosekTools)
csd = try_import(:CSDP)
scs = try_import(:SCS)

# Semidefinite factories
sdp_factories = MOI.OptimizerWithAttributes[]
# Need at least Mosek 8 for sosdemo3 to pass; see:
# https://github.com/JuliaOpt/Mosek.jl/issues/92
# and at least Mosek 8.0.0.41 for sosdemo6 to pass; see:
# https://github.com/JuliaOpt/Mosek.jl/issues/98
mos && push!(sdp_factories, optimizer_with_attributes(MosekTools.Mosek.Optimizer, "QUIET" => true))
# Currently, need to create a file param.csdp to avoid printing, see https://github.com/JuliaOpt/CSDP.jl/issues/15
# TODO uncomment
# csd && push!(sdp_factories, optimizer_with_attributes(CSDP.Optimizer, "printlevel" => 0))
# iscsdp(factory) = occursin("CSDP", string(factory.constructor))
# # Need 54000 iterations for sosdemo3 to pass on Linux 64 bits
# # With 55000, sosdemo3 passes for every platform except Windows 64 bits on AppVeyor
# scs && push!(sdp_factories, optimizer_with_attributes(SCS.Optimizer, "eps" => 1e-6, "max_iters" => 60000, "verbose" => 0))
# isscs(factory) = occursin("SCS", string(factory.constructor))
