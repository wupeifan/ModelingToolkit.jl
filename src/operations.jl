# Parameterize by T so that way it can be Vector{Expression} which is defined after
struct Operation <: AbstractOperation
    op::Function
    args::Vector{Expression}
end

# Operations use isequal for equality since == is an Operation
function Base.isequal(x::Operation,y::Operation)
    x.op == y.op && all(isequal.(x.args,y.args))
end
Base.isequal(x::Operation,y::Number) = false
Base.isequal(x::Number,y::Operation) = false
Base.isequal(x::Operation,y::Void) = false
Base.isequal(x::Void,y::Operation) = false

# This might be a bad idea
function Base.:(!=)(x::Operation,y)
    !isequal(x,y)
end
Base.convert(::Type{Operation},x::Variable) = Operation(identity,x)


# Don't recurse inversion for Jacobians
Base.inv(x::Operation) = x

function Base.Expr(O::Operation)
    Expr(:call, Symbol(O.op), Expr.(O.args)...)
end

Base.show(io::IO,O::Operation) = print(io,string(Expr(O)))

# Bigger printing
# Is there a way to just not have this as the default?
function Base.parse(::Type{Operation},ex::Expr)
    f = ex.args[1]
    operands = ex.args[2:end]
    if ex.head == :call && any(x -> x isa Expr, ex.args)
        args = Expression[parse(Operation,o) for o in operands]
        parse(Operation, f, args)
    else
        parse(Operation, f, Expression[parse(Operation,o) for o in operands])
    end
end
Base.parse(::Type{Operation},x::Expression) = x
Base.parse(::Type{Operation},sym::Symbol,args) = Operation(eval(sym), args)
Base.parse(::Type{Operation},x::Union{Symbol, Number}) = x
