using ModelingToolkit, LinearAlgebra, DiffEqJump, Test
MT = ModelingToolkit

@parameters t k[1:20]
@variables A(t) B(t) C(t) D(t)
rxs = [Reaction(k[1], nothing, [A]),            # 0 -> A
       Reaction(k[2], [B], nothing),            # B -> 0
       Reaction(k[3],[A],[C]),                  # A -> C
       Reaction(k[4], [C], [A,B]),              # C -> A + B
       Reaction(k[5], [C], [A], [1], [2]),      # C -> A + A
       Reaction(k[6], [A,B], [C]),              # A + B -> C
       Reaction(k[7], [B], [A], [2], [1]),      # 2B -> A
       Reaction(k[8], [A,B], [A,C]),            # A + B -> A + C
       Reaction(k[9], [A,B], [C,D]),            # A + B -> C + D
       Reaction(k[10], [A], [C,D], [2], [1,1]), # 2A -> C + D
       Reaction(k[11], [A], [A,B], [2], [1,1]), # 2A -> A + B
       Reaction(k[12], [A,B,C], [C,D], [1,3,4], [2, 3]),          # A+3B+4C -> 2C + 3D
       Reaction(k[13], [A,B], nothing, [3,1], nothing),           # 3A+B -> 0
       Reaction(k[14], nothing, [A], nothing, [2]),               # 0 -> 2A
       Reaction(k[15]*A/(2+A), [A], nothing; only_use_rate=true), # A -> 0 with custom rate
       Reaction(k[16], [A], [B]; only_use_rate=true),             # A -> B with custom rate.
       Reaction(k[17]*A*exp(B), [C], [D], [2], [1]),              # 2C -> D with non constant rate.
       Reaction(k[18]*B, nothing, [B], nothing, [2]),             # 0 -> 2B with non constant rate.
       Reaction(k[19]*t, [A], [B]),                                # A -> B with non constant rate.
       Reaction(k[20]*t*A, [B,C], [D],[2,1],[2])                  # 2A +B -> 2C with non constant rate.
  ]
rs = ReactionSystem(rxs,t,[A,B,C,D],k)
odesys = convert(ODESystem,rs)
sdesys = convert(SDESystem,rs)

# hard coded ODE rhs
function oderhs(u,k,t)
       A = u[1]; B = u[2]; C = u[3]; D = u[4];
       du = zeros(eltype(u),4)
       du[1] = k[1] - k[3]*A + k[4]*C + 2*k[5]*C - k[6]*A*B + k[7]*B^2/2 - k[9]*A*B - k[10]*A^2 - k[11]*A^2/2 - k[12]*A*B^3*C^4/144 - 3*k[13]*A^3*B/6 + 2*k[14] - k[15]*A/(2+A) - k[16] - k[19]*t*A
       du[2] = -k[2]*B + k[4]*C - k[6]*A*B - k[7]*B^2 - k[8]*A*B - k[9]*A*B + k[11]*A^2/2 - 3*k[12]*A*B^3*C^4/144 - k[13]*A^3*B/6 + k[16] + 2*k[18]*B + k[19]*t*A - 2*k[20]*t*A*B^2*C
       du[3] = k[3]*A - k[4]*C - k[5]*C  + k[6]*A*B + k[8]*A*B + k[9]*A*B + k[10]*A^2/2 - 2*k[12]*A*B^3*C^4/144 - 2*k[17]*A*exp(B)*C^2/2 - k[20]*t*A*B^2*C
       du[4] = k[9]*A*B + k[10]*A^2/2 + 3*k[12]*A*B^3*C^4/144 + k[17]*A*exp(B)*C^2/2 + 2*k[20]*t*A*B^2*C
       du
end

# sde noise coefs
function sdenoise(u,k,t)
       A = u[1]; B = u[2]; C = u[3]; D = u[4];
       G = zeros(eltype(u),length(k),length(u))
       z = zero(eltype(u))

       G = [sqrt(k[1]) z  z z;
            z -sqrt(k[2]*B) z z;
            -sqrt(k[3]*A) z sqrt(k[3]*A) z;
            sqrt(k[4]*C) sqrt(k[4]*C) -sqrt(k[4]*C) z;
            2*sqrt(k[5]*C) z -sqrt(k[5]*C) z;
            -sqrt(k[6]*A*B) -sqrt(k[6]*A*B) sqrt(k[6]*A*B) z;
            sqrt(k[7]*B^2/2) -2*sqrt(k[7]*B^2/2) z z;
            z -sqrt(k[8]*A*B) sqrt(k[8]*A*B) z;
            -sqrt(k[9]*A*B) -sqrt(k[9]*A*B) sqrt(k[9]*A*B) sqrt(k[9]*A*B);
            -2*sqrt(k[10]*A^2/2) z sqrt(k[10]*A^2/2) sqrt(k[10]*A^2/2);
            -sqrt(k[11]*A^2/2) sqrt(k[11]*A^2/2) z z;
            -sqrt(k[12]*A*B^3*C^4/144) -3*sqrt(k[12]*A*B^3*C^4/144) -2*sqrt(k[12]*A*B^3*C^4/144) 3*sqrt(k[12]*A*B^3*C^4/144);
            -3*sqrt(k[13]*A^3*B/6) -sqrt(k[13]*A^3*B/6) z z;
            2*sqrt(k[14]) z z z;
            -sqrt(k[15]*A/(2+A)) z z z;
            -sqrt(k[16]) sqrt(k[16]) z z;
            z z -2*sqrt(k[17]*A*exp(B)*C^2/2) sqrt(k[17]*A*exp(B)*C^2/2);
            z 2*sqrt(k[18]*B) z z;
            -sqrt(k[19]*t*A) sqrt(k[19]*t*A) z z;
            z -2*sqrt(k[20]*t*A*B^2*C) -sqrt(k[20]*t*A*B^2*C) +2*sqrt(k[20]*t*A*B^2*C)]'
       return G
end

# test by evaluating drift and diffusion terms
p  = rand(length(k))
u  = rand(length(k))
t  = 0.
du = oderhs(u,p,t)
G  = sdenoise(u,p,t)
sdesys = convert(SDESystem,rs)
sf = SDEFunction{false}(sdesys, states(rs), parameters(rs))
du2 = sf.f(u,p,t)
@test norm(du-du2) < 100*eps()
G2 = sf.g(u,p,t)
@test norm(G-G2) < 100*eps()

# test with JumpSystem
js = convert(JumpSystem, rs)

@test all(map(i -> typeof(js.eqs[i]) <: DiffEqJump.MassActionJump, 1:14))
@test all(map(i -> typeof(js.eqs[i]) <: DiffEqJump.ConstantRateJump, 15:18))
@test all(map(i -> typeof(js.eqs[i]) <: DiffEqJump.VariableRateJump, 19:20))

pars = rand(length(k)); u0 = rand(1:100,4); time = rand();
jumps = Vector{Union{ConstantRateJump, MassActionJump, VariableRateJump}}(undef,length(js.eqs))

jumps[1] = MassActionJump(pars[1], Vector{Pair{Int,Int}}(), [1 => 1]);
jumps[2] = MassActionJump(pars[2], [2 => 1], [2 => -1]);
jumps[3] = MassActionJump(pars[3], [1 => 1], [1 => -1, 3 => 1]);
jumps[4] = MassActionJump(pars[4], [3 => 1], [1 => 1, 2 => 1, 3 => -1]);
jumps[5] = MassActionJump(pars[5], [3 => 1], [1 => 2, 3 => -1]);
jumps[6] = MassActionJump(pars[6], [1 => 1, 2 => 1], [1 => -1, 2 => -1, 3 => 1]);
jumps[7] = MassActionJump(pars[7], [2 => 2], [1 => 1, 2 => -2]);
jumps[8] = MassActionJump(pars[8], [1 => 1, 2 => 1], [2 => -1, 3 => 1]);
jumps[9] = MassActionJump(pars[9], [1 => 1, 2 => 1], [1 => -1, 2 => -1, 3 => 1, 4 => 1]);
jumps[10] = MassActionJump(pars[10], [1 => 2], [1 => -2, 3 => 1, 4 => 1]);
jumps[11] = MassActionJump(pars[11], [1 => 2], [1 => -1, 2 => 1]);
jumps[12] = MassActionJump(pars[12], [1 => 1, 2 => 3, 3 => 4], [1 => -1, 2 => -3, 3 => -2, 4 => 3]);
jumps[13] = MassActionJump(pars[13], [1 => 3, 2 => 1], [1 => -3, 2 => -1]);
jumps[14] = MassActionJump(pars[14], Vector{Pair{Int,Int}}(), [1 => 2]);

jumps[15] = ConstantRateJump((u,p,t) -> p[15]*u[1]/(2+u[1]), integrator -> (integrator.u[1] -= 1))
jumps[16] = ConstantRateJump((u,p,t) -> p[16], integrator -> (integrator.u[1] -= 1; integrator.u[2] += 1;))
jumps[17] = ConstantRateJump((u,p,t) -> p[17]*u[1]*exp(u[2])*binomial(u[3],2), integrator -> (integrator.u[3] -= 2; integrator.u[4] += 1))
jumps[18] = ConstantRateJump((u,p,t) -> p[18]*u[2], integrator -> (integrator.u[2] += 2))

jumps[19] = VariableRateJump((u,p,t) -> p[19]*u[1]*t, integrator -> (integrator.u[1] -= 1; integrator.u[2] += 1))
jumps[20] = VariableRateJump((u,p,t) -> p[20]*t*u[1]*binomial(u[2],2)*u[3], integrator -> (integrator.u[2] -= 2; integrator.u[3] -= 1; integrator.u[4] += 2))

statetoid = Dict(convert(Variable,state) => i for (i,state) in enumerate(states(js)))
parammap  = Dict(convert(Variable,param) => pars[i] for (i,param) in enumerate(parameters(js)))
pvars = parameters(js)
param_context = Module()
for (i, pval) in enumerate(pars)        
    psym = Symbol(pvars[i])
    Base.eval(param_context, :($psym = $pval))
end
for i = 1:14
  maj = MT.assemble_maj(js, js.eqs[i], statetoid, parammap, param_context)
  @test abs(jumps[i].scaled_rates - maj.scaled_rates) < 100*eps()
  @test jumps[i].reactant_stoch == maj.reactant_stoch
  @test jumps[i].net_stoch == maj.net_stoch
end
for i = 15:18
  (i==16) && continue
  crj = MT.assemble_crj(js, js.eqs[i], statetoid)
  @test abs(crj.rate(u0,p,time) - jumps[i].rate(u0,p,time)) < 100*eps()
  fake_integrator1 = (u=zeros(4),p=p,t=0); fake_integrator2 = deepcopy(fake_integrator1);
  crj.affect!(fake_integrator1); jumps[i].affect!(fake_integrator2);
  @test fake_integrator1 == fake_integrator2
end
for i = 19:20
  crj = MT.assemble_vrj(js, js.eqs[i], statetoid)
  @test abs(crj.rate(u0,p,time) - jumps[i].rate(u0,p,time)) < 100*eps()
  fake_integrator1 = (u=zeros(4),p=p,t=0.); fake_integrator2 = deepcopy(fake_integrator1);
  crj.affect!(fake_integrator1); jumps[i].affect!(fake_integrator2);
  @test fake_integrator1 == fake_integrator2
end
