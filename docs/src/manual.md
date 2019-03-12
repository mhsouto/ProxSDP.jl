# Manual

## Building problems with JuMP.jl

Currently the easiest ways to pass problems to ProxSDP is through [JuMP](https://github.com/JuliaOpt/JuMP.jl) or MathOptInterface (v0.8).

The main caveat is that currently ProxSDP must have one and only one PSD variable, no other variables are allowed.

In the test folder one can find MOI implementations of some problems: MIMO, Sensor Localization, Random SDPs and sdplib problems.

## Solver arguments

Argument | Description | Type | Values (default)
--- | --- | --- |  ---
log_verbose | print evolution of the process | `Bool` |  `false`
log_freq | print evoluition of the process every n iterations | `Int` |  `100`
timer_verbose | Outputs a time logger | `Bool` |  `false`
max_iter | Maximum number of iterations | `Int` |  `100000`
tol_primal | Primal error tolerance | `Float64` |  `1e-4`
tol_dual | Dual error tolerance | `Float64` |  `1e-4`
tol_eig | Tolerance associated with PSD cone | `Float64` |  `1e-6`
tol_soc | Tolerance associated with SOC cone | `Float64` |  `1e-6`
initial_theta | Initial over relaxation parameter | `Float64` |  `1.0`
initial_beta | Initial primal/dual step ratio | `Float64` |  `1.0`
min_beta | Minimum primal/dual step ratio | `Float64` |  `1e-2`
max_beta | Maximum primal/dual step ratio | `Float64` |  `1e+8`
convergence_window | Minimum number of iterations to update target rank | `Int` |  `100`
max_linsearch_steps | Maximum number of iterations for linesearch | `Int` |  `1000`
full_eig_decomp | Flag for using full eigenvalue decomposition | `Bool` |  `false`

## JuMP example

A quick JuMP example:

```julia
using ProxSDP, JuMP

# Create a JuMP model using ProxSDP as the solver
model = Model(with_optimizer(ProxSDP.Optimizer, log_verbose=true))

# Create a Positive Semidefinite variable
# Currently ProxSDP is only able to hold one PSD
# variable and no other variable
@variable(model, X[1:2,1:2], PSD)

# but you can define pieces of the one PSD
# variable to hold other variable as in the
# Canonical SDP format
x = X[1,1]
y = X[2,2]

# There is no limits on linear constraints
# one can define as many as wanted
@constraint(model, ub_x, x <= 2)

@constraint(model, ub_y, y <= 30)

@constraint(model, con, 1x + 5y <= 3)

# ProxSDP supports maximization or minimization
# of linear functions
@objective(model, Max, 5x + 3 * y)

# Then we can solve the model
JuMP.optimize!(model)

# And ask for results!
JuMP.objective_value(model)

JuMP.value(x)

JuMP.value(y)
```

### Referencing

The first version of the paper can be found [here](https://arxiv.org/abs/1810.05231).

```
@article{souto2018exploiting,
  title={Exploiting Low-Rank Structure in Semidefinite Programming by Approximate Operator Splitting},
  author={Souto, Mario and Garcia, Joaquim D and Veiga, {\'A}lvaro},
  journal={arXiv preprint arXiv:1810.05231},
  year={2018}
}
```