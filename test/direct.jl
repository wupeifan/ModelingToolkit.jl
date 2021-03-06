using ModelingToolkit, StaticArrays, LinearAlgebra, SparseArrays
using DiffEqBase
using Test

canonequal(a, b) = isequal(simplify(a), simplify(b))

# Calculus
@parameters t σ ρ β
@variables x y z

eqs = [σ*(y-x),
       x*(ρ-z)-y,
       x*y - β*z]

simpexpr = [
   :(σ * (y - x))
   :(x * (ρ - z) - y)
   :(x * y - β * z)
   ]

for i in 1:3
   @test ModelingToolkit.simplified_expr.(eqs)[i] == simpexpr[i]
   @test ModelingToolkit.simplified_expr.(eqs)[i] == simpexpr[i]
end

∂ = ModelingToolkit.jacobian(eqs,[x,y,z])
for i in 1:3
    ∇ = ModelingToolkit.gradient(eqs[i],[x,y,z])
    @test canonequal(∂[i,:],∇)
end

@test all(canonequal.(ModelingToolkit.gradient(eqs[1],[x,y,z]),[σ * -1,σ,0]))
@test all(canonequal.(ModelingToolkit.hessian(eqs[1],[x,y,z]),0))

Joop,Jiip = eval.(ModelingToolkit.build_function(∂,[x,y,z],[σ,ρ,β],t))
J = Joop([1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J isa Matrix
J2 = copy(J)
Jiip(J2,[1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J2 == J

Joop,Jiip = eval.(ModelingToolkit.build_function(vcat(∂,∂),[x,y,z],[σ,ρ,β],t))
J = Joop([1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J isa Matrix
J2 = copy(J)
Jiip(J2,[1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J2 == J

Joop,Jiip = eval.(ModelingToolkit.build_function(hcat(∂,∂),[x,y,z],[σ,ρ,β],t))
J = Joop([1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J isa Matrix
J2 = copy(J)
Jiip(J2,[1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J2 == J

∂3 = cat(∂,∂,dims=3)
Joop,Jiip = eval.(ModelingToolkit.build_function(∂3,[x,y,z],[σ,ρ,β],t))
J = Joop([1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test size(J) == (3,3,2)
J2 = copy(J)
Jiip(J2,[1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J2 == J

s∂ = sparse(∂)
@test nnz(s∂) == 8
Joop,Jiip = eval.(ModelingToolkit.build_function(s∂,[x,y,z],[σ,ρ,β],t,linenumbers=true))
J = Joop([1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test length(nonzeros(s∂)) == 8
J2 = copy(J)
Jiip(J2,[1.0,2.0,3.0],[1.0,2.0,3.0],1.0)
@test J2 == J

# Function building

@parameters σ() ρ() β()
@variables x y z
eqs = [σ*(y-x),
       x*(ρ-z)-y,
       x*y - β*z]
f1,f2 = ModelingToolkit.build_function(eqs,[x,y,z],[σ,ρ,β])
f = eval(f1)
out = [1.0,2,3]
o1 = f([1.0,2,3],[1.0,2,3])
f = eval(f2)
f(out,[1.0,2,3],[1.0,2,3])
@test all(o1 .== out)

function test_worldage()
   @parameters σ() ρ() β()
   @variables x y z
   eqs = [σ*(y-x),
          x*(ρ-z)-y,
          x*y - β*z]
   f, f_iip = ModelingToolkit.build_function(eqs,[x,y,z],[σ,ρ,β];expression=Val{false})
   out = [1.0,2,3]
   o1 = f([1.0,2,3],[1.0,2,3])
   f_iip(out,[1.0,2,3],[1.0,2,3])
end
test_worldage()

## No parameters
@variables x y z
eqs = [(y-x)^2,
       x*(x-z)-y,
       x*y - y*z]
f1,f2 = ModelingToolkit.build_function(eqs,[x,y,z])
f = eval(f1)
out = zeros(3)
o1 = f([1.0,2,3])
f = eval(f2)
f(out,[1.0,2,3])
@test all(out .== o1)

function test_worldage()
   @variables x y z
   eqs = [(y-x)^2,
          x*(x-z)-y,
          x*y - y*z]
   f, f_iip = ModelingToolkit.build_function(eqs,[x,y,z];expression=Val{false})
   out = zeros(3)
   o1 = f([1.0,2,3])
   f_iip(out,[1.0,2,3])
end
test_worldage()

@test_nowarn muladd(x, y, ModelingToolkit.Constant(0))
@test promote(x, ModelingToolkit.Constant(0)) == (x, identity(0))
@test_nowarn [x, y, z]'
