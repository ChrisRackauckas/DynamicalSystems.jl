# Mathematical functions that do some stuff
# very fast or very conveniently.
# Also includes helper functions

#####################################################################################
#                                Pairwse Distance                                   #
#####################################################################################
using NearestNeighbors, StaticArrays
export min_pairwise_distance

# min_pairwise_distance contributed by Kristoffer Carlsson
"""
    min_pairwise_distance(data) -> (min_pair, min_dist)
Calculate the minimum pairwise distance in the data (`Matrix`, `Vector{Vector}` or
`Dataset`). Return the index pair
of the datapoints that have the minimum distance, as well as its value.
"""
function min_pairwise_distance(cts::AbstractMatrix)
    if size(cts, 1) > size(cts, 2)
        error("Points must be close (transpose the Matrix)")
    end
    tree = KDTree(cts)
    min_d = Inf
    min_pair = (0, 0)
    for p in 1:size(cts, 2)
        inds, dists = knn(tree, view(cts, :, p), 1, false, i -> i == p)
        ind, dist = inds[1], dists[1]
        if dist < min_d
            min_d = dist
            min_pair = (p, ind)
        end
    end
    return min_pair, min_d
end

min_pairwise_distance(d::Dataset) = min_pairwise_distance(d.data)
function min_pairwise_distance(
    pts::Union{Vector{Vector{T}}, Vector{SVector{D,T}}}) where {D,T<:Real}
    tree = KDTree(pts)
    min_d = eltype(pts[1])(Inf)
    min_pair = (0, 0)
    for p in 1:length(pts)
        inds, dists = knn(tree, pts[p], 1, false, i -> i == p)
        ind, dist = inds[1], dists[1]
        if dist < min_d
            min_d = dist
            min_pair = (p, ind)
        end
    end
    return min_pair, min_d
end

#####################################################################################
#                                 Minima and Maxima                                 #
#####################################################################################
function minima(data::Dataset{D, T, V}) where {D, T<:Real, V}
    m = zeros(T, D) .+ T(Inf)
    for point in data
        for i in 1:D
            if point[i] < m[i]
                m[i] = point[i]
            end
        end
    end
    return SVector{D,T}(m)
end

function maxima(data::Dataset{D, T, V}) where {D, T<:Real, V}
    m = zeros(T, D) .+ T(-Inf)
    for point in data
        for i in 1:D
            if point[i] > m[i]
                m[i] = point[i]
            end
        end
    end
    return SVector{D, T}(m)
end

#####################################################################################
#                                      QR                                           #
#####################################################################################
function qr_gs(A::SMatrix{D,D,T}) where {D, T<:Real}
    es = SVector{D,T}[]
    push!(es, normalize(A[:,1]))
    for k in 2:D
        ak = A[:, k]
        uk = ak - sum(dot(ak, es[i])*es[i] for i in 1:k-1 )
        push!(es, normalize(uk))
    end
    Q::SMatrix = hcat(es...)
    Rdiag = SVector{D,T}(ntuple(k -> dot(A[:, k],es[k]), Val{D}))
    return Q, Rdiag
end

# qr_sq contributed by Max Roßner
"""
    qr_sq(m::AbstractMatrix) -> (Q, R)
Perform QR decomposition on a square matrix `m`.
This method is faster than `Base.qr` for small matrices.
"""
function qr_sq(m::AbstractMatrix)    # faster version for square matrices
	s = size(m, 1)
	t = zeros(s, s)
	v = zeros(s)
	r = copy(m)
	w = 0.

	for i=1:(s-1)
		w = 0.
		for j=i:s
			v[j] = r[j, i]
			w += v[j]*v[j]
		end

		v[i] += (r[1, i] >= 0 ? 1. : -1.)*sqrt(w)
		w = 0.

		for j=i:s w += v[j]*v[j] end
		w = 2.0/w

		for j=1:s, k=1:s
			t[j, k] = k == j ? 1. : 0.
			if j>=i && k>=i
			    t[j, k] -= w*v[j]*v[k]
			end
		end

		for j=1:s
			for k=1:s
				v[k] = r[k, j]
			end

			for l=1:s
				w = 0.
				for h=1:s
					w += v[h]*t[l, h]
				end
				r[l, j] = w
			end
		end
	end

	for j=1:(s-1), k=(j+1):s
	 	r[k, j] = 0.
	end

	return (m*inv(r), r)
end

function qr_sq(m::SArray{Tuple{D,D},T,2,L}) where {D, T<:Real, L}
	s = D
    r = convert(Array, m)
	t = zeros(r)
	v = zeros(T, s)
	w = 0.0

	for i=1:(s-1)
		w = 0.
		for j=i:s
			v[j] = r[j, i]
			w += v[j]*v[j]
		end

		v[i] += (r[1, i] >= 0 ? 1. : -1.)*sqrt(w)
		w = 0.

		for j=i:s w += v[j]*v[j] end
		w = 2.0/w

		for j=1:s, k=1:s
			t[j, k] = k == j ? 1. : 0.
			if j>=i && k>=i
			    t[j, k] -= w*v[j]*v[k]
			end
		end

		for j=1:s
			for k=1:s
				v[k] = r[k, j]
			end

			for l=1:s
				w = 0.
				for h=1:s
					w += v[h]*t[l, h]
				end
				r[l, j] = w
			end
		end
	end

	for j=1:(s-1), k=(j+1):s
	 	r[k, j] = 0.0
	end
    R = SMatrix{D,D}(r)
	return (m*inv(R), R)
end
