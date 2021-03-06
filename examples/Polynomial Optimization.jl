# # Polynomial Optimization

#md # [![](https://mybinder.org/badge_logo.svg)](@__BINDER_ROOT_URL__/generated/Polynomial Optimization.ipynb)
#md # [![](https://img.shields.io/badge/show-nbviewer-579ACA.svg)](@__NBVIEWER_ROOT_URL__/generated/Polynomial Optimization.ipynb)
# **Contributed by**: Benoît Legat

# ## Introduction

# Consider the polynomial optimization problem of
# minimizing the polynomial $x^3 - x^2 + 2xy -y^2 + y^3$
# over the polyhedron defined by the inequalities $x \ge 0, y \ge 0$ and $x + y \geq 1$.

using Test #src
using DynamicPolynomials
@polyvar x y
p = x^3 - x^2 + 2x*y -y^2 + y^3
using SumOfSquares
S = @set x >= 0 && y >= 0 && x + y >= 1
p(x=>1, y=>0), p(x=>1//2, y=>1//2), p(x=>0, y=>1)

# The optimal solutions are $(x, y) = (1, 0)$ and $(x, y) = (0, 1)$ with objective value $0$ but [Ipopt](https://github.com/jump-dev/Ipopt.jl/) only finds the local minimum $(1/2, 1/2)$ with objective value $1/4$.

import Ipopt
model = Model(optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0))
@variable(model, a >= 0)
@variable(model, b >= 0)
@constraint(model, a + b >= 1)
@NLobjective(model, Min, a^3 - a^2 + 2a*b - b^2 + b^3)
optimize!(model)
@test termination_status(model) == MOI.LOCALLY_SOLVED #src
@show termination_status(model)
@test value(a) ≈ 0.5 rtol=1e-5 #src
@show value(a)
@test value(b) ≈ 0.5 rtol=1e-5 #src
@show value(b)
@test objective_value(model) ≈ 0.25 rtol=1e-5 #src
@show objective_value(model)

# Note that the problem can be written equivalently as follows using [registered functions](https://jump.dev/JuMP.jl/v0.21/nlp/#User-defined-Functions-1).

using Ipopt
model = Model(optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0))
@variable(model, a >= 0)
@variable(model, b >= 0)
@constraint(model, a + b >= 1)
peval(a, b) = p(x=>a, y=>b)
register(model, :peval, 2, peval, autodiff=true)
@NLobjective(model, Min, peval(a, b))
optimize!(model)
@test termination_status(model) == MOI.LOCALLY_SOLVED #src
@show termination_status(model)
@test value(a) ≈ 0.5 rtol=1e-5 #src
@show value(a)
@test value(b) ≈ 0.5 rtol=1e-5 #src
@show value(b)
@test objective_value(model) ≈ 0.25 rtol=1e-5 #src
@show objective_value(model)

## Sum-of-Squares approach

# We will now see how to find the optimal solution using Sum of Squares Programming.
# We first need to pick an SDP solver, see [here](http://jump.dev/JuMP.jl/dev/installation/#Getting-Solvers-1) for a list of the available choices.

import CSDP
solver = optimizer_with_attributes(CSDP.Optimizer, MOI.Silent() => true)

# A Sum-of-Squares certificate that $p \ge \alpha$ over the domain `S`, ensures that $\alpha$ is a lower bound to the polynomial optimization problem.
# The following program searches for the largest upper bound and finds zero.

model = SOSModel(solver)
@variable(model, α)
@objective(model, Max, α)
@constraint(model, c3, p >= α, domain = S)
optimize!(model)
@test termination_status(model) == MOI.OPTIMAL #src
@show termination_status(model)
@test objective_value(model) ≈ 0.0 atol=1e-5 #src
@show objective_value(model)

# Using the solution $(1/2, 1/2)$ found by Ipopt of objective value $1/4$
# and this certificate of lower bound $0$ we know that the optimal objective value is in the interval $[0, 1/4]$
# but we still do not know what it is (if we consider that we did not try the solutions $(1, 0)$ and $(0, 1)$ as done in the introduction).
# If the dual of the constraint `c3` was atomic, its atoms would have given optimal solutions of objective value $0$ but that is not the case.

ν3 = moment_matrix(c3)
@test extractatoms(ν3, 1e-3) === nothing #src
extractatoms(ν3, 1e-3) # Returns nothing as the dual is not atomic

# Fortunately, there is a hierarchy of programs with increasingly better bounds that can be solved until we get one with atom dual variables.
# This comes from the way the Sum-of-Squares constraint with domain `S` is formulated.
# The polynomial $p - \alpha$ is guaranteed to be nonnegative over the domain `S` if there exists Sum-of-Squares polynomials $s_0$, $s_1$, $s_2$, $s_3$ such that
# $$ p - \alpha = s_0 + s_1 x + s_2 y + s_3 (x + y - 1). $$
# Indeed, in the domain `S`, $x$, $y$ and $x + y - 1$ are nonnegative so the right-hand side is a sum of squares hence is nonnegative.
# Once the degrees of $s_1$, $s_2$ and $s_3$ have been decided, the degree needed for $s_0$ will be determined but we have a freedom in choosing the degrees of $s_1$, $s_2$ and $s_3$.
# By default, they are chosen so that the degrees of $s_1 x$, $s_2 y$ and $s_3 (x + y - 1)$ match those of $p - \alpha$ but this can be overwritten using the $maxdegree$ keyword argument.

# ### The maxdegree keyword argument

# The maximum total degree (i.e. maximum sum of the exponents of $x$ and $y$) of the monomials of $p$ is 3 so the constraint in the program above is equivalent to `@constraint(model, p >= α, domain = S, maxdegree = 3)`.
# That is, since $x$, $y$ and $x + y - 1$ have total degree 1, the sum of squares polynomials $s_1$, $s_2$ and $s_3$ have been chosen with maximum total degree $2$.
# Since these polynomials are sums of squares, their degree must be even so the next maximum total degree to try is 4.
# For this reason, the keywords `maxdegree = 4` and `maxdegree = 5` have the same effect in this example.
# In general, if the polynomials in the domain are not all odd or all even, each value of `maxdegree` has different effect in the choice of the maximum total degree of $s_i$.

model = SOSModel(solver)
@variable(model, α)
@objective(model, Max, α)
@constraint(model, c5, p >= α, domain = S, maxdegree = 5)
optimize!(model)
@test termination_status(model) == MOI.OPTIMAL #src
@show termination_status(model)
@test objective_value(model) ≈ 0.0 atol=1e-5 #src
@show objective_value(model)

# This time, the dual variable is atomic as it is the moments of the measure
# $$0.5 \delta(x-1, y) + 0.5 \delta(x, y-1)$$
# where $\delta(x, y)$ is the dirac measure centered at $(0, 0)$.
# Therefore the program provides both a certificate that $0$ is a lower bound and a certificate that it is also an upper bound since it is attained at the global minimizers $(1, 0)$ and $(0, 1)$.

ν5 = moment_matrix(c5)
atoms5 = extractatoms(ν5, 1e-3) #src
@test atoms5.atoms[1].weight ≈ 0.5 rtol=1e-2 #src
@test atoms5.atoms[2].weight ≈ 0.5 rtol=1e-2 #src
@test atoms5.atoms[1].center[2:-1:1] ≈ atoms5.atoms[2].center[1:2] rtol=1e-2 #src
extractatoms(ν5, 1e-3)

# ## A deeper look into atom extraction

# The `extractatoms` function requires a `ranktol` argument that we have set to `1e-3` in the preceding section.
# This argument is used to transform the dual variable into a system of polynomials equations whose solutions give the atoms.
# This transformation uses the SVD decomposition of the moment matrix and discards the equations corresponding to a singular value lower than `ranktol`.
# When this system of equation has an infinite number of solutions, `extractatoms` concludes that the measure is not atomic.
# For instance, with `maxdegree = 3`, we obtain the system
# $$x + y = 1$$
# which contains a whole line of solution.
# This explains `extractatoms` returned `nothing`.

ν3 = moment_matrix(c3)
SumOfSquares.MultivariateMoments.computesupport!(ν3, 1e-3)
@test length(ν3.support.I.p) == 1 #src

# With `maxdegree = 5`, we obtain the system
# \begin{align}
#   x + y & = 1\\
#   y^2 & = y\\
#   xy & = 0\\
#   x^2 + y & = 1
# \end{align}

ν5 = moment_matrix(c5)
SumOfSquares.MultivariateMoments.computesupport!(ν5, 1e-3)

# This system can be reduced to the equivalent system
# \begin{align}
#   x + y & = 1\\
#   y^2 & = y
# \end{align}
# which has the solutions $(0, 1)$ and $(1, 0)$.

SemialgebraicSets.computegröbnerbasis!(ideal(ν5.support))
ν5.support
@test length(ν5.support.I.p) == 2 #src

# The function `extractatoms` then reuse the matrix of moments to find the weights $1/2$, $1/2$ corresponding to the diracs centered respectively at $(0, 1)$ and $(1, 0)$.
# This details the how the function obtained the result
# $$0.5 \delta(x-1, y) + 0.5 \delta(x, y-1)$$
# given in the previous section.
