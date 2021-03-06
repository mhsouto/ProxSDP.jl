push!(Base.LOAD_PATH,joinpath(dirname(@__FILE__),"..",".."))

using ProxSDP, MathOptInterface, Test, LinearAlgebra, Random, SparseArrays, DelimitedFiles

using LinearAlgebra
LinearAlgebra.symmetric_type(::Type{MathOptInterface.VariableIndex}) = MathOptInterface.VariableIndex
LinearAlgebra.symmetric(v::MathOptInterface.VariableIndex, ::Symbol) = v
LinearAlgebra.transpose(v::MathOptInterface.VariableIndex) = v

const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIB = MOI.Bridges
const MOIU = MOI.Utilities

const cache = MOIU.UniversalFallback(MOIU.Model{Float64}())

const optimizer = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(
        tol_gap = 1e-6, tol_feasibility= 1e-6,
        # max_iter = 100_000,
        time_limit = 3., #seconds FAST
        warn_on_limit = true,
        # log_verbose = true, log_freq = 100000
        ))
const optimizer_slow = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(
        tol_gap = 1e-6, tol_feasibility= 1e-6,
        # max_iter = 100_000,
        time_limit = 30., #seconds
        warn_on_limit = true,
        # log_verbose = true, log_freq = 100000
        ))
const optimizer_high_acc = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(
        tol_primal = 1e-7, tol_dual = 1e-7,
        tol_gap = 1e-7, tol_feasibility = 1e-7,
        # log_verbose = true, log_freq = 1000
        ))
const optimizer_low_acc = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(
        tol_gap = 1e-3, tol_feasibility = 1e-3,
        # log_verbose = true, log_freq = 1000
        ))
const optimizer_full = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(full_eig_decomp = true, tol_gap = 1e-4, tol_feasibility = 1e-4))
const optimizer_print = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(log_freq = 10, log_verbose = true, timer_verbose = true, extended_log = true, extended_log2 = true,
    tol_gap = 1e-4, tol_feasibility = 1e-4))
const optimizer_lowacc_arpack = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(eigsolver = 1, tol_gap = 1e-3, tol_feasibility = 1e-3, log_verbose = false))
const optimizer_lowacc_krylovkit = MOIU.CachingOptimizer(cache,
    ProxSDP.Optimizer(eigsolver = 2, tol_gap = 1e-3, tol_feasibility = 1e-3, log_verbose = false))
const config = MOIT.TestConfig(atol=1e-3, rtol=1e-3, infeas_certificates = true)
const config_conic = MOIT.TestConfig(atol=1e-3, rtol=1e-3, duals = true, infeas_certificates = true)
# const config_conic_nodual = MOIT.TestConfig(atol=1e-3, rtol=1e-3, duals = false, infeas_certificates = true)

@testset "SolverName" begin
    @test MOI.get(optimizer, MOI.SolverName()) == "ProxSDP"
end

@testset "supports_default_copy_to" begin
    @test MOIU.supports_allocate_load(ProxSDP.Optimizer(), false)
    @test !MOIU.supports_allocate_load(ProxSDP.Optimizer(), true)
end

@testset "Unit" begin
    bridged = MOIB.full_bridge_optimizer(optimizer, Float64)
    MOIT.unittest(bridged, config,[
        # not supported attributes
        "number_threads",
        # Quadratic functions are not supported
        "solve_qcp_edge_cases", "solve_qp_edge_cases",
        # Integer and ZeroOne sets are not supported
        "solve_integer_edge_cases", "solve_objbound_edge_cases",
        "solve_zero_one_with_bounds_1",
        "solve_zero_one_with_bounds_2",
        "solve_zero_one_with_bounds_3",
        # farkas proof
        "solve_farkas_interval_upper",
        "solve_farkas_interval_lower",
        "solve_farkas_equalto_upper",
        "solve_farkas_equalto_lower",
        "solve_farkas_variable_lessthan_max",
        "solve_farkas_variable_lessthan",
        "solve_farkas_lessthan",
        "solve_farkas_greaterthan",
        ]
    )
    # TODO:
    bridged_slow = MOIB.full_bridge_optimizer(optimizer_slow, Float64)
    # MOIT.solve_farkas_interval_upper(bridged_slow, config)
    # MOIT.solve_farkas_interval_lower(bridged, config)
    # MOIT.solve_farkas_equalto_upper(bridged_slow, config)
    # MOIT.solve_farkas_equalto_lower(bridged, config)
    # MOIT.solve_farkas_variable_lessthan_max(bridged_slow, config)
    MOIT.solve_farkas_variable_lessthan(bridged_slow, config)
    # MOIT.solve_farkas_lessthan(bridged_slow, config)
    # MOIT.solve_farkas_greaterthan(bridged, config)
end

@testset "MOI Continuous Linear" begin
    bridged = MOIB.full_bridge_optimizer(optimizer, Float64)
    # MOIT.linear8atest(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    # MOIT.linear8btest(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    # MOIT.linear8ctest(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    # MOIT.linear12test(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    MOIT.contlineartest(bridged, config, [
        # infeasible/unbounded
        "linear8a",
        #"linear8b", "linear8c", "linear12",
        # poorly conditioned
        "linear10",
        "linear5",
        "linear9",
        # primalstart not accepted
        "partial_start",
        ]
    )
    MOIT.linear8atest(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    MOIT.linear9test(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    MOIT.linear5test(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
    MOIT.linear10test(MOIB.full_bridge_optimizer(optimizer_high_acc, Float64), config)
end

@testset "MOI Continuous Conic" begin
    MOIT.contconictest(MOIB.full_bridge_optimizer(optimizer, Float64), config_conic, [
        # bridge: some problem with square psd
        "rootdets",
        # exp cone
        "logdet", "exp", "dualexp",
        # pow cone
        "pow","dualpow",
        # other cones
        "relentr",
        # infeasible/unbounded
        # "lin3", "lin4",
        # See https://travis-ci.com/blegat/SolverTests/jobs/268551133
        # geomean2v: Test Failed at /home/travis/.julia/dev/MathOptInterface/src/Test/contconic.jl:1328
        # Expression: MOI.get(model, MOI.TerminationStatus()) == config.optimal_status
        #  Evaluated: INFEASIBLE_OR_UNBOUNDED::TerminationStatusCode = 6 == OPTIMAL::TerminationStatusCode = 1
        # "geomean2v", "geomean2f", , "rotatedsoc2", "psdt2", 
        # "normone2", "norminf2", "rotatedsoc2"#
        # slow to find certificate
        "normone2",
        ]
    )
    # # these fail due to infeasibility certificate not being disabled
    # MOIT.norminf2test(MOIB.full_bridge_optimizer(optimizer, Float64), config_conic_nodual)
    MOIT.normone2test(MOIB.full_bridge_optimizer(optimizer_slow, Float64), config_conic)
    # # requires certificates always
    # MOIT.rotatedsoc2test(MOIB.full_bridge_optimizer(optimizer, Float64), config_conic_nodual)
end

@testset "Simple LP" begin

    bridged = MOIB.full_bridge_optimizer(optimizer, Float64)
    MOI.empty!(bridged)
    @test MOI.is_empty(bridged)

    # add 10 variables - only diagonal is relevant
    X = MOI.add_variables(bridged, 2)

    # add sdp constraints - only ensuring positivenesse of the diagonal
    vov = MOI.VectorOfVariables(X)

    c1 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(2.0, X[1]),
            MOI.ScalarAffineTerm(1.0, X[2])
        ], 0.0), MOI.EqualTo(4.0))

    c2 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(1.0, X[1]),
            MOI.ScalarAffineTerm(2.0, X[2])
        ], 0.0), MOI.EqualTo(4.0))

    b1 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(1.0, X[1])
        ], 0.0), MOI.GreaterThan(0.0))

    b2 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(1.0, X[2])
        ], 0.0), MOI.GreaterThan(0.0))

    MOI.set(bridged, 
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([-4.0, -3.0], [X[1], X[2]]), 0.0)
        )
    MOI.set(bridged, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(bridged)

    obj = MOI.get(bridged, MOI.ObjectiveValue())

    @test obj ≈ -9.33333 atol = 1e-2

    Xr = MOI.get(bridged, MOI.VariablePrimal(), X)

    @test Xr ≈ [1.3333, 1.3333] atol = 1e-2

end

@testset "Simple LP with 2 1D SDP" begin

    bridged = MOIB.full_bridge_optimizer(optimizer, Float64)
    MOI.empty!(bridged)
    @test MOI.is_empty(bridged)

    # add 10 variables - only diagonal is relevant
    X = MOI.add_variables(bridged, 2)

    # add sdp constraints - only ensuring positivenesse of the diagonal
    vov = MOI.VectorOfVariables(X)

    c1 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(2.0, X[1]),
            MOI.ScalarAffineTerm(1.0, X[2])
        ], 0.0), MOI.EqualTo(4.0))

    c2 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(1.0, X[1]),
            MOI.ScalarAffineTerm(2.0, X[2])
        ], 0.0), MOI.EqualTo(4.0))

    b1 = MOI.add_constraint(bridged, 
        MOI.VectorOfVariables([X[1]]), MOI.PositiveSemidefiniteConeTriangle(1))

    b2 = MOI.add_constraint(bridged, 
        MOI.VectorOfVariables([X[2]]), MOI.PositiveSemidefiniteConeTriangle(1))

    MOI.set(bridged, 
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([-4.0, -3.0], [X[1], X[2]]), 0.0)
        )
    MOI.set(bridged, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(bridged)

    obj = MOI.get(bridged, MOI.ObjectiveValue())

    @test obj ≈ -9.33333 atol = 1e-2

    Xr = MOI.get(bridged, MOI.VariablePrimal(), X)

    @test Xr ≈ [1.3333, 1.3333] atol = 1e-2

end

@testset "LP in SDP EQ form" begin

    bridged = MOIB.full_bridge_optimizer(optimizer, Float64)
    MOI.empty!(bridged)
    @test MOI.is_empty(bridged)

    # add 10 variables - only diagonal is relevant
    X = MOI.add_variables(bridged, 10)

    # add sdp constraints - only ensuring positivenesse of the diagonal
    vov = MOI.VectorOfVariables(X)
    cX = MOI.add_constraint(bridged, vov, MOI.PositiveSemidefiniteConeTriangle(4))

    c1 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(2.0, X[1]),
            MOI.ScalarAffineTerm(1.0, X[3]),
            MOI.ScalarAffineTerm(1.0, X[6])
        ], 0.0), MOI.EqualTo(4.0))

    c2 = MOI.add_constraint(bridged, 
        MOI.ScalarAffineFunction([
            MOI.ScalarAffineTerm(1.0, X[1]),
            MOI.ScalarAffineTerm(2.0, X[3]),
            MOI.ScalarAffineTerm(1.0, X[10])
        ], 0.0), MOI.EqualTo(4.0))

    MOI.set(bridged, 
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([-4.0, -3.0], [X[1], X[3]]), 0.0)
        )
    MOI.set(bridged, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(bridged)

    obj = MOI.get(bridged, MOI.ObjectiveValue())

    @test obj ≈ -9.33333 atol = 1e-2

    Xr = MOI.get(bridged, MOI.VariablePrimal(), X)

    @test Xr ≈ [1.3333, .0, 1.3333, .0, .0, .0, .0, .0, .0, .0] atol = 1e-2

end

@testset "LP in SDP INEQ form" begin

    MOI.empty!(optimizer)
    @test MOI.is_empty(optimizer)

    # add 10 variables - only diagonal is relevant
    X = MOI.add_variables(optimizer, 3)

    # add sdp constraints - only ensuring positivenesse of the diagonal
    vov = MOI.VectorOfVariables(X)
    cX = MOI.add_constraint(optimizer, vov, MOI.PositiveSemidefiniteConeTriangle(2))

    c1 = MOI.add_constraint(optimizer, 
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.([1,1],[
            MOI.ScalarAffineTerm(2.0, X[1]),
            MOI.ScalarAffineTerm(1.0, X[3]),
        ]), [-4.0]), MOI.Nonpositives(1))

    c2 = MOI.add_constraint(optimizer, 
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.([1,1],[
            MOI.ScalarAffineTerm(1.0, X[1]),
            MOI.ScalarAffineTerm(2.0, X[3]),
        ]), [-4.0]), MOI.Nonpositives(1))

    MOI.set(optimizer, 
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), 
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([4.0, 3.0], [X[1], X[3]]), 0.0)
        )
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    MOI.optimize!(optimizer)

    obj = MOI.get(optimizer, MOI.ObjectiveValue())

    @test obj ≈ 9.33333 atol = 1e-2

    Xr = MOI.get(optimizer, MOI.VariablePrimal(), X)

    @test Xr ≈ [1.3333, .0, 1.3333] atol = 1e-2

    c1_d = MOI.get(optimizer, MOI.ConstraintDual(), c1)
    c2_d = MOI.get(optimizer, MOI.ConstraintDual(), c2)

end

@testset "SDP from MOI" begin
    # min X[1,1] + X[2,2]    max y
    #     X[2,1] = 1         [0   y/2     [ 1  0
    #                         y/2 0    <=   0  1]
    #     X >= 0              y free
    # Optimal solution:
    #
    #     ⎛ 1   1 ⎞
    # X = ⎜       ⎟           y = 2
    #     ⎝ 1   1 ⎠
    MOI.empty!(optimizer)
    @test MOI.is_empty(optimizer)

    X = MOI.add_variables(optimizer, 3)

    vov = MOI.VectorOfVariables(X)
    cX = MOI.add_constraint(optimizer, vov, MOI.PositiveSemidefiniteConeTriangle(2))

    c = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[2]))], [-1.0]), MOI.Zeros(1))

    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(1.0, [X[1], X[3]]), 0.0))

    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL

    @test MOI.get(optimizer, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(optimizer, MOI.DualStatus()) == MOI.FEASIBLE_POINT

    @test MOI.get(optimizer, MOI.ObjectiveValue()) ≈ 2 atol=1e-2

    Xv = ones(3)
    @test MOI.get(optimizer, MOI.VariablePrimal(), X) ≈ Xv atol=1e-2
    # @test MOI.get(optimizer, MOI.ConstraintPrimal(), cX) ≈ Xv atol=1e-2

    # @test MOI.get(optimizer, MOI.ConstraintDual(), c) ≈ 2 atol=1e-2
    # @show MOI.get(optimizer, MOI.ConstraintDual(), c)

end

@testset "Double SDP from MOI" begin
    # solve simultaneously two of these:
    # min X[1,1] + X[2,2]    max y
    #     X[2,1] = 1         [0   y/2     [ 1  0
    #                         y/2 0    <=   0  1]
    #     X >= 0              y free
    # Optimal solution:
    #
    #     ⎛ 1   1 ⎞
    # X = ⎜       ⎟           y = 2
    #     ⎝ 1   1 ⎠
    MOI.empty!(optimizer)
    @test MOI.is_empty(optimizer)

    X = MOI.add_variables(optimizer, 3)
    Y = MOI.add_variables(optimizer, 3)

    vov = MOI.VectorOfVariables(X)
    vov2 = MOI.VectorOfVariables(Y)
    cX = MOI.add_constraint(optimizer, vov, MOI.PositiveSemidefiniteConeTriangle(2))
    cY = MOI.add_constraint(optimizer, vov2, MOI.PositiveSemidefiniteConeTriangle(2))

    c = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[2]))], [-1.0]), MOI.Zeros(1))
    c2 = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, Y[2]))], [-1.0]), MOI.Zeros(1))

    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(1.0, [X[1], X[end], Y[1], Y[end]]), 0.0))

    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL

    @test MOI.get(optimizer, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(optimizer, MOI.DualStatus()) == MOI.FEASIBLE_POINT

    @test MOI.get(optimizer, MOI.ObjectiveValue()) ≈ 2*2 atol=1e-2

    Xv = ones(3)
    @test MOI.get(optimizer, MOI.VariablePrimal(), X) ≈ Xv atol=1e-2
    Yv = ones(3)
    @test MOI.get(optimizer, MOI.VariablePrimal(), Y) ≈ Yv atol=1e-2
    # @test MOI.get(optimizer, MOI.ConstraintPrimal(), cX) ≈ Xv atol=1e-2

    # @test MOI.get(optimizer, MOI.ConstraintDual(), c) ≈ 2 atol=1e-2
    # @show MOI.get(optimizer, MOI.ConstraintDual(), c)

end

@testset "SDP with duplicates from MOI" begin

    cache = MOIU.UniversalFallback(MOIU.Model{Float64}());
    #optimizer0 = SCS.Optimizer(linear_solver=SCS.Direct, eps=1e-8);
    optimizer0 = ProxSDP.Optimizer()#linear_solver=SCS.Direct, eps=1e-8);
    MOI.empty!(cache);
    optimizer1 = MOIU.CachingOptimizer(cache, optimizer0);
    optimizer = MOIB.full_bridge_optimizer(optimizer1, Float64);

    MOI.empty!(optimizer)

    x = MOI.add_variable(optimizer)
    X = [x, x, x]

    vov = MOI.VectorOfVariables(X)
    cX = MOI.add_constraint(optimizer, vov, MOI.PositiveSemidefiniteConeTriangle(2))

    c = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[2]))], [-1.0]), MOI.Zeros(1))

    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(1.0, [X[1], X[3]]), 0.0))

    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL

    @test MOI.get(optimizer, MOI.PrimalStatus()) == MOI.FEASIBLE_POINT
    @test MOI.get(optimizer, MOI.DualStatus()) == MOI.FEASIBLE_POINT

    @test MOI.get(optimizer, MOI.ObjectiveValue()) ≈ 2 atol=1e-2

    Xv = ones(3)
    @test MOI.get(optimizer, MOI.VariablePrimal(), X) ≈ Xv atol=1e-2

end

@testset "SDP from Wikipedia" begin
    # https://en.wikipedia.org/wiki/Semidefinite_programming
    MOI.empty!(optimizer)
    @test MOI.is_empty(optimizer)

    X = MOI.add_variables(optimizer, 6)

    vov = MOI.VectorOfVariables(X)
    cX = MOI.add_constraint(optimizer, vov, MOI.PositiveSemidefiniteConeTriangle(3))

    cd1 = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[1]))], [-1.0]), MOI.Zeros(1))
    cd1 = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[3]))], [-1.0]), MOI.Zeros(1))
    cd1 = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[6]))], [-1.0]), MOI.Zeros(1))

    c12_ub = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[2]))], [0.1]), MOI.Nonpositives(1))   # x <= -0.1 -> x + 0.1 <= 0
    c12_lb = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(-1.0, X[2]))], [-0.2]), MOI.Nonpositives(1)) # x >= -0.2 -> -x + -0.2 <= 0

    c23_ub = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(1.0, X[5]))], [-0.5]), MOI.Nonpositives(1)) # x <= 0.5 ->  x - 0.5 <= 0
    c23_lb = MOI.add_constraint(optimizer, MOI.VectorAffineFunction([MOI.VectorAffineTerm(1,MOI.ScalarAffineTerm(-1.0, X[5]))], [0.4]), MOI.Nonpositives(1)) # x >= 0.4 -> -x + 0.4 <= 0

    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.(1.0, [X[4]]), 0.0))

    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    MOI.optimize!(optimizer)

    obj = MOI.get(optimizer, MOI.ObjectiveValue())
    @test obj ≈ -0.978 atol=1e-2

    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MAX_SENSE)

    MOI.optimize!(optimizer)

    obj = MOI.get(optimizer, MOI.ObjectiveValue())
    @test obj ≈ 0.872 atol=1e-2

end

@testset "MIMO Sizes" begin
    include("base_mimo.jl")
    include("moi_mimo.jl")
    for i in 2:5
        @testset "MIMO n = $(i)" begin 
            moi_mimo(optimizer, 123, i, test = true)
        end
    end
end

# hitting time limit
# probably infeasible/unbounded
# @testset "RANDSDP Sizes" begin
#     include("base_randsdp.jl")
#     include("moi_randsdp.jl")
#     for n in 10:11, m in 10:11
#         @testset "RANDSDP n=$n, m=$m" begin 
#             moi_randsdp(optimizer, 123, n, m, test = true, atol = 1e-1)
#         end
#     end
# end

# This problems are too large for Travis
@testset "SDPLIB Sizes" begin
    datapath = joinpath(dirname(@__FILE__), "data")
    include("base_sdplib.jl")
    include("moi_sdplib.jl")
    @testset "EQPART" begin
        # badly conditioned
        # moi_sdplib(optimizer_low_acc, joinpath(datapath, "gpp124-1.dat-s"), test = true)
        moi_sdplib(optimizer_low_acc, joinpath(datapath, "gpp124-2.dat-s"), test = true)
        moi_sdplib(optimizer_lowacc_arpack, joinpath(datapath, "gpp124-2.dat-s"), test = true)
        moi_sdplib(optimizer_lowacc_krylovkit, joinpath(datapath, "gpp124-2.dat-s"), test = true)
        # moi_sdplib(optimizer, joinpath(datapath, "gpp124-3.dat-s"), test = true)
        # moi_sdplib(optimizer, joinpath(datapath, "gpp124-4.dat-s"), test = true)
    end
    @testset "MAX CUT" begin
        moi_sdplib(optimizer_low_acc, joinpath(datapath, "mcp124-1.dat-s"), test = true)
        moi_sdplib(optimizer_lowacc_arpack, joinpath(datapath, "mcp124-1.dat-s"), test = true)
        moi_sdplib(optimizer_lowacc_krylovkit, joinpath(datapath, "mcp124-1.dat-s"), test = true)
        # moi_sdplib(optimizer, joinpath(datapath, "mcp124-2.dat-s"), test = true)
        # moi_sdplib(optimizer, joinpath(datapath, "mcp124-3.dat-s"), test = true)
        # moi_sdplib(optimizer, joinpath(datapath, "mcp124-4.dat-s"), test = true)
    end
end

@testset "Sensor Localization" begin
    include("base_sensorloc.jl")
    include("moi_sensorloc.jl")
    for n in 5:5:10
        moi_sensorloc(optimizer, 0, n, test = true)
    end
end

@testset "Full eig" begin
    MOIT.psdt0vtest(
        MOIB.full_bridge_optimizer(optimizer_full, Float64),
        MOIT.TestConfig(atol=1e-3, rtol=1e-3, duals = false)
        )
end

@testset "Print" begin
    MOIT.linear15test(optimizer_print, MOIT.TestConfig(atol=1e-3, rtol=1e-3))
end

@testset "Unsupported argument" begin
    MOI.empty!(cache)
    @test_throws ErrorException  optimizer_unsupportedarg = MOIU.CachingOptimizer(cache, ProxSDP.Optimizer(unsupportedarg = 10))
    # @test_throws ErrorException MOI.optimize!(optimizer_unsupportedarg)
end

include("test_terminationstatus.jl")
