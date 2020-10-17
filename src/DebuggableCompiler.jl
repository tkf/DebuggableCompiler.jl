module DebuggableCompiler

export @enter_code_typed

using Debugger: @enter
using InteractiveUtils: gen_call_with_extracted_types_and_kwargs

include("julia/compiler.jl")
include("julia/base.jl")

"""
    @enter_code_typed [optimize=false] [debuginfo=:none] f(x)

Step into the compiler.
"""
macro enter_code_typed(ex0...)
    gen_call_with_extracted_types_and_kwargs(__module__, :enter_code_typed, ex0)
end

function enter_code_typed(args...; kwargs...)
    @enter _Base.code_typed(args...; kwargs...)
end

end
