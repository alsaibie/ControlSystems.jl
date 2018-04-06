# Model interconnections

@doc """
`series(s1::LTISystem, s2::LTISystem)`

Connect systems in series, equivalent to `s2*s1`
""" ->
series(s1::LTISystem, s2::LTISystem) = s2*s1

@doc """
`series(s1::LTISystem, s2::LTISystem)`

Connect systems in parallel, equivalent to `s2+s1`
""" ->
parallel(s1::LTISystem, s2::LTISystem) = s1 + s2

append() = LTISystem[]
@doc """
`append(systems::StateSpace...), append(systems::TransferFunction...)`

Append systems in block diagonal form
""" ->
function append(systems::StateSpace...)
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    A = blkdiag([s.A for s in systems]...)
    B = blkdiag([s.B for s in systems]...)
    C = blkdiag([s.C for s in systems]...)
    D = blkdiag([s.D for s in systems]...)
    return StateSpace(A, B, C, D, Ts, states, inputs, outputs)
end

function append(systems::TransferFunction...)
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    mat = blkdiag([s.matrix for s in systems]...)
    return TransferFunction(mat, Ts)
end

append(systems::LTISystem...) = append(promote(systems...)...)

function Base.vcat(systems::StateSpace...)
    # Perform checks
    nu = systems[1].nu
    if !all([s.nu == nu for s in systems])
        error("All systems must have same input dimension")
    end
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    A = blkdiag([s.A for s in systems]...)
    B = vcat([s.B for s in systems]...)
    C = blkdiag([s.C for s in systems]...)
    D = vcat([s.D for s in systems]...)

    return StateSpace(A, B, C, D, Ts)
end

function Base.vcat(systems::TransferFunction...)
    # Perform checks
    nu = systems[1].nu
    if !all([s.nu == nu for s in systems])
        error("All systems must have same input dimension")
    end
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    mat = vcat([s.matrix for s in systems]...)
    return TransferFunction(mat, Ts)
end

Base.vcat(systems::LTISystem...) = vcat(promote(systems...)...)

function Base.vcat{T<:Real}(systems::Union{VecOrMat{T},T,TransferFunction}...)
    if Base.promote_typeof(systems...) <: TransferFunction
        vcat(map(e->convert(TransferFunction,e),systems)...)
    else
        cat(1,systems...)
    end
end

function Base.hcat(systems::StateSpace...)
    # Perform checks
    ny = systems[1].ny
    if !all([s.ny == ny for s in systems])
        error("All systems must have same output dimension")
    end
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    A = blkdiag([s.A for s in systems]...)
    B = blkdiag([s.B for s in systems]...)
    C = hcat([s.C for s in systems]...)
    D = hcat([s.D for s in systems]...)

    return StateSpace(A, B, C, D, Ts)
end

function Base.hcat(systems::TransferFunction...)
    # Perform checks
    ny = systems[1].ny
    if !all([s.ny == ny for s in systems])
        error("All systems must have same output dimension")
    end
    Ts = systems[1].Ts
    if !all([s.Ts == Ts for s in systems])
        error("Sampling time mismatch")
    end
    mat = hcat([s.matrix for s in systems]...)
    return TransferFunction(mat, Ts)
end

Base.hcat(systems::LTISystem...) = hcat(promote(systems...)...)


# TODO: Fix this
function Base.hcat(systems::Union{Number,AbstractVecOrMat{<:Number},TransferFunction}...)
    if Base.promote_typeof(systems...) <: TransferFunction
        hcat(map(e->convert(TransferFunction,e),systems)...)
    else
        cat(Val{2},systems...)
    end
end




function Base.hvcat(rows::Tuple{Vararg{Int}}, systems::Union{Number,AbstractVecOrMat{<:Number},TransferFunction}...)
    T = Base.promote_typeof(systems...)
    nbr = length(rows)  # number of block rows
    rs = Array{T,1}(nbr)
    a = 1
    for i = 1:nbr
        rs[i] = hcat(convert.(T,systems[a:a-1+rows[i]])...)
        a += rows[i]
    end
    vcat(rs...)
end

# function _get_common_sampling_time(sys_vec::Union{AbstractVector{LTISystem},AbstractVecOrMat{<:Number},Number})
#     Ts = -1.0 # Initalize corresponding to undefined sampling time
#
#     for sys in sys_vec
#         if !all([s.Ts == Ts for s in systems])
#             error("Sampling time mismatch")
#         end
#     end
#
# end


# function Base.hcat{T<:Number}(systems::Union{T,AbstractVecOrMat{T},TransferFunction}...)
#     S = promote_type(map(e->typeof(e),systems)...) # TODO: Should be simplified
#
#     idx_first_tf = findfirst(e -> isa(e, TransferFunction), systems)
#     Ts = sys_tuple[idx_first_tf].Ts
#
#     if S <: TransferFunction
#         hcat(map(e->convert(TransferFunction,e),systems)...)
#     else
#         cat(2,systems...)
#     end
# end

# TODO: could use cat([1,2], mats...) instead
# Empty definition to get rid of warning
Base.blkdiag() = []
function Base.blkdiag(mats::Matrix...)
    rows = Int[size(m, 1) for m in mats]
    cols = Int[size(m, 2) for m in mats]
    T = eltype(mats[1])
    for ind=1:length(mats)
        T = promote_type(T, eltype(mats[ind]))
    end
    res = zeros(T, sum(rows), sum(cols))
    m = 1
    n = 1
    for ind=1:length(mats)
        mat = mats[ind]
        i = rows[ind]
        j = cols[ind]
        res[m:m + i - 1, n:n + j - 1] = mat
        m += i
        n += j
    end
    return res
end