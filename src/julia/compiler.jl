baremodule _Compiler

import Base
using Core.Compiler: SimpleVector
for n in Base.names(Core.Compiler; all = true, imported = true)
    n === :typeinf_code && continue
    Base.startswith(Base.string(n), "#") && continue
    if Base.isdefined(Core.Compiler, n)
        Base.@eval _Compiler using Core.Compiler: $n
    end
end

#! format: off

function typeinf_code(interp::AbstractInterpreter, method::Method, @nospecialize(atypes), sparams::SimpleVector, run_optimizer::Bool)
    mi = specialize_method(method, atypes, sparams)::MethodInstance
    # ccall(:jl_typeinf_begin, Cvoid, ())
    result = InferenceResult(mi)
    frame = InferenceState(result, false, interp)
    frame === nothing && return (nothing, Any)
    if typeinf(interp, frame) && run_optimizer
        opt_params = OptimizationParams(interp)
        opt = OptimizationState(frame, opt_params, interp)
        optimize(opt, opt_params, result.result)
        opt.src.inferred = true
    end
    # ccall(:jl_typeinf_end, Cvoid, ())
    frame.inferred || return (nothing, Any)
    return (frame.src, widenconst(result.result))
end

end
