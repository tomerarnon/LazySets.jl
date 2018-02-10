import Base:∈,
            convert

export Zonotope,
       order,
       minkowski_sum,
       linear_map,
       scale,
       ngens,
       reduce_order

"""
    Zonotope{N<:Real} <: AbstractPointSymmetricPolytope{N}

Type that represents a zonotope.

### Fields

- `center`     -- center of the zonotope
- `generators` -- matrix; each column is a generator of the zonotope

### Notes

Mathematically, a zonotope is defined as the set

```math
Z = \\left\\{ c + ∑_{i=1}^p ξ_i g_i,~~ ξ_i \\in [-1, 1]~~ ∀ i = 1,…, p \\right\\},
```
where ``c \\in \\mathbb{R}^n`` is its *center* and ``\\{g_i\\}_{i=1}^p``,
``g_i \\in \\mathbb{R}^n``, is the set of *generators*.
This characterization defines a zonotope as the finite Minkowski sum of line
elements.
Zonotopes can be equivalently described as the image of a unit infinity-norm
ball in ``\\mathbb{R}^n`` by an affine transformation.

- `Zonotope(center::AbstractVector{N},
            generators::AbstractMatrix{N}) where {N<:Real}`

- `Zonotope(center::AbstractVector{N},
            generators_list::AbstractVector{T}
           ) where {N<:Real, T<:AbstractVector{N}}`

### Examples

A two-dimensional zonotope with given center and set of generators:

```jldoctest zonotope_label
julia> Z = Zonotope([1.0, 0.0], 0.1*eye(2))
LazySets.Zonotope{Float64}([1.0, 0.0], [0.1 0.0; 0.0 0.1])
julia> dim(Z)
2
```

Compute its vertices:

```jldoctest zonotope_label
julia> vertices_list(Z)
4-element Array{Array{Float64,1},1}:
 [0.9, -0.1]
 [1.1, -0.1]
 [1.1, 0.1]
 [0.9, 0.1]
```

Evaluate the support vector in a given direction:

```jldoctest zonotope_label
julia> σ([1., 1.], Z)
2-element Array{Float64,1}:
 1.1
 0.1
```

Alternative constructor: A zonotope in two dimensions with three generators:

```jldoctest
julia> Z = Zonotope(ones(2), [[1., 0.], [0., 1.], [1., 1.]])
LazySets.Zonotope{Float64}([1.0, 1.0], [1.0 0.0 1.0; 0.0 1.0 1.0])
julia> Z.generators
2×3 Array{Float64,2}:
 1.0  0.0  1.0
 0.0  1.0  1.0
```
"""
struct Zonotope{N<:Real} <: AbstractPointSymmetricPolytope{N}
    center::AbstractVector{N}
    generators::AbstractMatrix{N}
end
# constructor from center and list of generators
Zonotope(center::AbstractVector{N},
         generators_list::AbstractVector{T}) where {N<:Real, T<:AbstractVector{N}} =
    Zonotope(center, hcat(generators_list...))


# --- AbstractPointSymmetric interface functions ---


"""
    center(Z::Zonotope{N})::Vector{N} where {N<:Real}

Return the center of a zonotope.

### Input

- `Z` -- zonotope

### Output

The center of the zonotope.
"""
function center(Z::Zonotope{N})::Vector{N} where {N<:Real}
    return Z.center
end


# --- AbstractPolytope interface functions ---


"""
    vertices_list(Z::Zonotope{N})::Vector{Vector{N}} where {N<:Real}

Return the vertices of a zonotope.

### Input

- `Z` -- zonotope

### Output

List of vertices.

### Notes

This implementation computes a convex hull.

For high dimensions, it would be preferable to develop a `vertex_iterator`
approach.
"""
function vertices_list(Z::Zonotope{N})::Vector{Vector{N}} where {N<:Real}
    p = ngens(Z)
    vlist = Vector{Vector{N}}()
    sizehint!(vlist, 2^p)

    for ξi in IterTools.product([[1, -1] for i = 1:p]...)
        push!(vlist, Z.center .+ Z.generators * collect(ξi))
    end

    return convex_hull!(vlist)
end


# --- LazySet interface functions ---


"""
    σ(d::AbstractVector{<:Real}, Z::Zonotope)::AbstractVector{<:Real}

Return the support vector of a zonotope in a given direction.

### Input

- `d` -- direction
- `Z` -- zonotope

### Output

Support vector in the given direction.
If the direction has norm zero, the vertex with ``ξ_i = 1 \\ \\ ∀ i = 1,…, p``
is returned.
"""
function σ(d::AbstractVector{<:Real}, Z::Zonotope)::AbstractVector{<:Real}
    return Z.center .+ Z.generators * sign_cadlag.(Z.generators.' * d)
end

"""
    ∈(x::AbstractVector{N}, Z::Zonotope{N})::Bool where {N<:Real}

Check whether a given point is contained in a zonotope.

### Input

- `x` -- point/vector
- `Z` -- zonotope

### Output

`true` iff ``x ∈ Z``.

### Algorithm

This implementation poses the problem as a linear equality system and solves it
using `Base.:\`.
A zonotope centered in the origin with generators ``g_i`` contains a point ``x``
iff ``x = ∑_{i=1}^p ξ_i g_i`` for some ``ξ_i \\in [-1, 1]~~ ∀ i = 1,…, p``.
Thus, we first ask for a solution and then check if it is in this Cartesian
product of intervals.

Other algorithms exist which test the feasibility of an LP.

### Examples

```jldoctest
julia> Z = Zonotope([1.0, 0.0], 0.1*eye(2));

julia> ∈([1.0, 0.2], Z)
false
julia> ∈([1.0, 0.1], Z)
true
```
"""
function ∈(x::AbstractVector{N}, Z::Zonotope{N})::Bool where {N<:Real}
    @assert length(x) == dim(Z)

    k = length(x)
    b = similar(x)
    one_N = one(N)
    minus_one_N = -one_N
    for i in 1:k
        # normalize by moving the zonotope to the origin
        b[i] = x[i] - Z.center[i]
    end
    # matrix A is just Z.generators

    try
        # results in LAPACKException or SingularException if not solvable
        res = Z.generators \ b

        for xi in res
            if xi > one_N || xi < minus_one_N
                return false
            end
        end
        return true
    catch
        return false
    end
end


# --- Zonotope functions ---


"""
    order(Z::Zonotope)::Rational

Return the order of a zonotope.

### Input

- `Z` -- zonotope

### Output

A rational number representing the order of the zonotope.

### Notes

The order of a zonotope is defined as the quotient of its number of generators
and its dimension.
"""
function order(Z::Zonotope)::Rational
    return ngens(Z) // dim(Z)
end

"""
    minkowski_sum(Z1::Zonotope, Z2::Zonotope)

Concrete Minkowski sum of a pair of zonotopes.

### Input

- `Z1` -- one zonotope
- `Z2` -- another zonotope

### Output

The zonotope obtained by summing the centers and concatenating the generators
of ``Z_1`` and ``Z_2``.
"""
function minkowski_sum(Z1::Zonotope, Z2::Zonotope)
    return Zonotope(Z1.center + Z2.center, [Z1.generators Z2.generators])
end

"""
    linear_map(M::AbstractMatrix, Z::Zonotope)

Concrete linear map of a zonotopes.

### Input

- `M` -- matrix
- `Z` -- zonotope

### Output

The zonotope obtained by applying the linear map to the center and generators
of ``Z``.
"""
function linear_map(M::AbstractMatrix, Z::Zonotope)
    c = M * Z.center
    gi = M * Z.generators
    return Zonotope(c, gi)
end

"""
    scale(α::Real, Z::Zonotope)

Concrete scaling of a zonotope.

### Input

- `α` -- scalar
- `Z` -- zonotope

### Output

The zonotope obtained by applying the numerical scale to the center and generators
of ``Z``.
"""
function scale(α::Real, Z::Zonotope)
    c = α .* Z.center
    gi = α .* Z.generators
    return Zonotope(c, gi)
end

"""
    ngens(Z::Zonotope)::Int

Return the number of generators of a zonotope.

### Input

- `Z` -- zonotope

### Output

Integer representing the number of generators.
"""
ngens(Z::Zonotope)::Int = size(Z.generators, 2)

"""
    reduce_order(Z::Zonotope, r)::Zonotope

Reduce the order of a zonotope by overapproximating with a zonotope with less
generators.

### Input

- `Z` -- zonotope
- `r` -- desired order

### Output

A new zonotope with less generators, if possible.

### Algorithm

This function implements the algorithm described in A. Girard's
*Reachability of Uncertain Linear Systems Using Zonotopes*, HSCC. Vol. 5. 2005.
"""
function reduce_order(Z::Zonotope{N}, r)::Zonotope{N} where {N<:Real}
    c, G = Z.center, Z.generators
    d, p = dim(Z), ngens(Z)

    if r * d >= p
        # do not reduce
        return Z
    end

    h = zeros(N, p)
    for i in 1:p
        h[i] = vecnorm(G[:, i], 1) - vecnorm(G[:, i], Inf)
    end
    ind = sortperm(h)

    m = p - floor(Int, d * (r - 1)) # subset of ngens that are reduced
    rg = G[:, ind[1:m]] # reduced generators

    # interval hull computation of reduced generators
    Gbox = diagm(sum(abs.(rg), 2)[:])
    if m+1 <= p
        Gnotred = G[:, ind[m+1:end]]
        Gred = [Gnotred Gbox]
    else
        Gred = Gbox
    end
    return Zonotope(c, Gred)
end
