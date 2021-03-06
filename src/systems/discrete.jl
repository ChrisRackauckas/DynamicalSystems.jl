using StaticArrays, ForwardDiff, Requires

export DiscreteDS, DiscreteDS1D, evolve, evolve!, timeseries, dimension

#####################################################################################
#                                   Constructors                                    #
#####################################################################################
"Abstract type representing discrete systems."
abstract type DiscreteDynamicalSystem <: DynamicalSystem end
"""
    DiscreteDS(state, eom [, jacob]) <: DynamicalSystem
`D`-dimensional discrete dynamical system (used for `D ≤ 10`).
## Fields:
* `state::SVector{D}` : Current state-vector of the system, stored in the data format
  of `StaticArray`'s `SVector`.
* `eom` (function) : The function that represents the system's equations of motion
  (also called vector field). The function is of the format: `eom(u) -> SVector`
  which means that given a state-vector `u` it returns an `SVector` containing the
  next state.
* `jacob::J` (function) : A function that calculates the system's jacobian matrix,
  based on the format: `jacob(u) -> SMatrix` which means that given a state-vector
  `u` it returns an `SMatrix` containing the Jacobian at that state.

If the `jacob` is not provided by the user, it is created efficiently
using the module `ForwardDiff`.
"""
mutable struct DiscreteDS{D, T<:Number, F, J} <: DiscreteDynamicalSystem
    state::SVector{D,T}
    eom::F
    jacob::J
end
# constructor without jacobian (uses ForwardDiff)
function DiscreteDS(u0::AbstractVector, eom)
    su0 = SVector{length(u0)}(u0)
    @inline ForwardDiff_jac(x) = ForwardDiff.jacobian(eom, x)
    return DiscreteDS(su0, eom, ForwardDiff_jac)
end
function DiscreteDS(u0::AbstractVector, eom, jac)
    D = length(u0)
    su0 = SVector{D}(u0)
    T = eltype(su0); F = typeof(eom); J = typeof(jac)
    return DiscreteDS{D, T, F, J}(su0, eom, jac)
end

"""
    DiscreteDS1D(state, eom [, deriv]) <: DynamicalSystem
One-dimensional discrete dynamical system.
## Fields:
* `state::Real` : Current state of the system.
* `eom::F` (function) : The function that represents the system's equation of motion:
  `eom(x) -> Real`.
* `deriv::D` (function) : A function that calculates the system's derivative given
  a state: `deriv(x) -> Real`. If it is not provided by the user
  it is created automatically using the module `ForwardDiff`.
"""
mutable struct DiscreteDS1D{S<:Real, F, D} <: DiscreteDynamicalSystem
    state::S
    eom::F
    deriv::D
end
function DiscreteDS1D(x0, eom)
    ForwardDiff_der(x) = ForwardDiff.derivative(eom, x)
    DiscreteDS1D(x0, eom, ForwardDiff_der)
end

dimension(ds::DiscreteDS) = length(ds.state)
dimension(::DiscreteDS1D) = 1

#####################################################################################
#                               System Evolution                                    #
#####################################################################################
"""
    evolve(ds::DynamicalSystem, T=1; diff_eq_kwargs = Dict()) -> final_state
Evolve a `ds` for total "time" `T` and return the `final_state` (does not change
`ds.state`).
For discrete systems `T` corresponds to steps and
thus it must be integer. See `timeseries` for using `diff_eq_kwargs`.

This function *does not store* any information about intermediate steps.
Use `timeseries` if you want to produce timeseries of the system. If you want to
perform step-by-step evolution of a continuous system, use
`ODEIntegrator(ds, t_final)` and
the `step!(integrator)` function provided by `DifferentialEquations`.

See also `evolve!`.
"""
function evolve(ds::DiscreteDynamicalSystem, N::Int = 1)
    st = ds.state
    f = ds.eom
    for i in 1:N
        st = f(st)
    end
    return st
end

"""
    evolve!(ds::DynamicalSystem, T; diff_eq_kwargs = Dict()) -> ds
Evolve (in-place) a dynamical system for total "time" `T`, setting the final
state as the system's state.
For discrete systems `T` corresponds to steps and
thus it must be integer. See `timeseries` for using `diff_eq_kwargs`.
See `timeseries` for using `diff_eq_kwargs`.

This function *does not store* any information about intermediate steps.
Use `timeseries` if you want to produce timeseries of the system. If you want to
perform step-by-step evolution of a continuous system, use
`ODEIntegrator(ds, t_final)` and
the `step!(integrator)` function provided by `DifferentialEquations`.

See also `evolve`.
"""
function evolve!(ds::DiscreteDynamicalSystem, N::Int = 1)
    st = ds.state
    ds.state = evolve(ds, N)
    return ds.state
end


"""
```julia
timeseries(ds::DynamicalSystem, T; kwargs...) -> dataset
```
Return a dataset what will contain the timeseries of the sytem,
after evolving it for time `T`. See `Dataset` for info on how to
manipulate this object.

For the discrete case, `T` is an integer and a `T×D` dataset is returned
(`D` is the system dimensionality). For the
continuous case, a `W×D` dataset is returned, with `W = length(0:dt:T)` with
`0:dt:T` representing the time vector (*not* returned).
## Keywords:
* `dt = 0.05` : (only for continuous) Time step of value output during the solving
  of the continuous system.
* `diff_eq_kwargs = Dict()` : (only for continuous) A dictionary `Dict{Symbol, ANY}`
  of keyword arguments
  passed into the `solve` of the `DifferentialEquations.jl` package,
  for example `Dict(:abstol => 1e-9)`. If you want to specify a solver,
  do so by using the symbol `:solver`, e.g.:
  `Dict(:solver => DP5(), :maxiters => 1e9)`. This requires you to have been first
  `using OrdinaryDiffEq` to access the solvers.
"""
function timeseries(ds::DiscreteDS, N::Real)
    st = ds.state
    ts = [st]
    f = ds.eom
    for i in 2:N
        st = f(st)
        push!(ts, st)
    end
    return Dataset(ts)
end

function timeseries(ds::DiscreteDS1D, N::Int)
    x = deepcopy(ds.state)
    f = ds.eom
    ts = Vector{typeof(x)}(N)
    ts[1] = x
    for i in 2:N
        x = f(x)
        ts[i] = x
    end
    return ts
end

#####################################################################################
#                                Pretty-Printing                                    #
#####################################################################################
import Base.show
function Base.show(io::IO, s::DiscreteDS{N, S, F, J}) where
    {N<:ANY, S<:ANY, F<:ANY, J<:ANY}
    print(io, "$N-dimensional discrete dynamical system:\n",
    " state: $(s.state)\n", " e.o.m.: $F\n", " jacobian: $J")
end

@require Juno begin
    function Juno.render(i::Juno.Inline, s::DiscreteDS{N, S, F, J}) where
        {N<:ANY, S<:ANY, F<:ANY, J<:ANY}
        t = Juno.render(i, Juno.defaultrepr(s))
        t[:head] = Juno.render(i, Text("$N-dimensional discrete dynamical system"))
        t
    end
end

# 1-D
function Base.show(io::IO, s::DiscreteDS1D{S, F, J}) where {S<:ANY, F<:ANY, J<:ANY}
    print(io, "1-dimensional discrete dynamical system:\n",
    "state: $(s.state)\n", "e.o.m.: $F\n", "jacobian: $J")
end
@require Juno begin
    function Juno.render(i::Juno.Inline, s::DiscreteDS1D{S, F, J}) where
        {S<:ANY, F<:ANY, J<:ANY}
        t = Juno.render(i, Juno.defaultrepr(s))
        t[:head] = Juno.render(i, Text("1-dimensional discrete dynamical system"))
        t
    end
end
