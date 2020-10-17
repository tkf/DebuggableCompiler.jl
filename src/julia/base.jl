#=
baremodule _Base

using ..DebuggableCompiler: _Compiler

import Base
for n in Base.names(Base; all = true, imported = true)
    n === :code_typed && continue
    n === :code_typed_by_type && continue
    Base.startswith(Base.string(n), "#") && continue
    if Base.isdefined(Base, n)
        Base.@eval _Base using Base: $n
    end
end
=#

module _Base

using ..DebuggableCompiler: _Compiler
using Base:
    IRShow,
    _methods_by_ftype,
    func_for_method_checked,
    get_world_counter,
    remove_linenums!,
    rewrap_unionall,
    to_tuple_type,
    unwrap_unionall

# Import some interesting functions so that `bp add optimize`
# etc. work:
using Core.Compiler: optimize, run_passes, replace_code_newstyle!

#! format: off

function code_typed(@nospecialize(f), @nospecialize(types=Tuple);
                    optimize=true,
                    debuginfo::Symbol=:default,
                    world = get_world_counter(),
                    interp = Core.Compiler.NativeInterpreter(world))
    if isa(f, Core.Builtin)
        throw(ArgumentError("argument is not a generic function"))
    end
    ft = Core.Typeof(f)
    if isa(types, Type)
        u = unwrap_unionall(types)
        tt = rewrap_unionall(Tuple{ft, u.parameters...}, types)
    else
        tt = Tuple{ft, types...}
    end
    return code_typed_by_type(tt; optimize, debuginfo, world, interp)
end

function code_typed_by_type(@nospecialize(tt::Type);
                            optimize=true,
                            debuginfo::Symbol=:default,
                            world = get_world_counter(),
                            interp = Core.Compiler.NativeInterpreter(world))
    ccall(:jl_is_in_pure_context, Bool, ()) && error("code reflection cannot be used from generated functions")
    if @isdefined(IRShow)
        debuginfo = IRShow.debuginfo(debuginfo)
    elseif debuginfo === :default
        debuginfo = :source
    end
    if debuginfo !== :source && debuginfo !== :none
        throw(ArgumentError("'debuginfo' must be either :source or :none"))
    end
    tt = to_tuple_type(tt)
    matches = _methods_by_ftype(tt, -1, world)
    if matches === false
        error("signature does not correspond to a generic function")
    end
    asts = []
    for match in matches
        meth = func_for_method_checked(match.method, tt, match.sparams)
        (code, ty) = _Compiler.typeinf_code(interp, meth, match.spec_types, match.sparams, optimize)
        code === nothing && error("inference not successful") # inference disabled?
        debuginfo === :none && remove_linenums!(code)
        push!(asts, code => ty)
    end
    return asts
end

end
