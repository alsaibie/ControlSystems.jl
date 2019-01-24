"""
A StateSpace model with a partioning imposed according to

A  | B1  B2
——— ————————
C1 | D11 D12
C2 | D21 D22

It corresponds to partioned input and output signals
u = [u1 u2]^T
y = [y1 y2]^T

"""
struct PartionedStateSpace{S}
    P::S
    nu1::Int
    ny1::Int
end


function getproperty(sys::PartionedStateSpace, d::Symbol)
    P = getfield(sys, :P)
    nu1 = getfield(sys, :nu1)
    ny1 = getfield(sys, :ny1)

    if d == :P
        return P
    elseif d == :nu1
        return nu1
    elseif d == :ny1
        return ny1
    elseif d == :A
        return P.A
    elseif d == :B1
        return P.B[:, 1:nu1]
    elseif d == :B2
        return P.B[:, nu1+1:end]
    elseif d == :C1
        return P.C[1:ny1, :]
    elseif d == :C2
        return P.C[ny1+1:end, :]
    elseif d == :D11
        return P.D[1:ny1, 1:nu1]
    elseif d == :D12
        return P.D[1:ny1, nu1+1:end]
    elseif d == :D21
        return P.D[ny1+1:end, 1:nu1]
    elseif d == :D22
        return P.D[ny1+1:end, nu1+1:end]
    else
        return getfield(P, d)
    end
end


# There should already exist a function like this somewhare?
function blkdiag(A1::Matrix{T1}, A2::Matrix{T2}) where {T1<:Number, T2<:Number}
    T = promote_type(T1, T2)

    dims1 = size(A1)
    dims2 = size(A2)

    A_new = zeros(Float64, dims1 .+ dims2)
    A_new[1:dims1[1], 1:dims1[2]] = A1
    A_new[dims1[1]+1:end, dims1[2]+1:end] = A2

    return A_new
end


function +(s1::PartionedStateSpace, s2::PartionedStateSpace)
    A = blkdiag(s1.A, s2.A)

    B = [[s1.B1; s2.B1] blkdiag(s1.B2, s2.B2)]

    C = [[s1.C1 s2.C1];
    blkdiag(s1.C2, s2.C2)]

    D = [(s1.D11 + s2.D11) s1.D12 s2.D12;
    [s1.D21; s2.D21] blkdiag(s1.D22, s2.D22)]

    P = StateSpace(A, B, C, D, 0) # How to handle discrete?
    PartionedStateSpace(P, s1.nu1 + s2.nu1, s1.ny1 + s2.ny1)
end





"""
    Series connection of partioned StateSpace systems.
"""
function *(s1::PartionedStateSpace, s2::PartionedStateSpace)
    A = [s1.A                           s1.B1*s2.C1;
    zeros(size(s2.A,1),size(s1.A,2))      s2.A]

    B = [s1.B1*s2.D11                         s1.B2           s1.B1*s2.D12;
    s2.B1              zeros(size(s2.B2,1),size(s1.B2,2))          s2.B2]

    C = [s1.C1                       s1.D11*s2.C1;
    s1.C2                        s1.D21*s2.C1;
    zeros(size(s2.C2,1),size(s1.C2,2))         s2.C2]

    D = [s1.D11*s2.D11           s1.D12        s1.D11*s2.D12;
    s1.D21*s2.D11           s1.D22        s1.D21*s2.D12;
    s2.D21          zeros(size(s2.D22,1),size(s1.D22,2))          s2.D22        ]

    P = StateSpace(A, B, C, D, 0)
    PartionedStateSpace(P, s2.nu1, s1.ny1)
end



# QUESTION: What about algebraic loops and well-posedness?! Perhaps issue warning if P1(∞)*P2(∞) > 1
function feedback(s1::PartionedStateSpace, s2::PartionedStateSpace)
    X_11 = (I + s2.D11*s1.D11)\[-s2.D11*s1.C1  -s2.C1]
    X_21 = (I + s1.D11*s2.D11)\[s1.C1  -s1.D11*s2.C1]

    # For the case of two outputs
    #    X_12 = [I   -s2.D11   -s2.D11*s1.D12   -s2.D12]
    #    X_22 = [s1.D11  I     s1.D12          -s1.D11*s2.D12]
    X_12 = (I + s2.D11*s1.D11)\[I      -s2.D11*s1.D12   -s2.D12]
    X_22 = (I + s1.D11*s2.D11)\[s1.D11   s1.D12          -s1.D11*s2.D12]

    A = [s1.B1 * X_11 ; s2.B1 * X_21] + blkdiag(s1.A, s2.A)

    B = [s1.B1 * X_12 ; s2.B1 * X_22]
    tmp = blkdiag(s1.B2, s2.B2)
    B[:, end-size(tmp,2)+1:end] .+= tmp

    C = [s1.D11 * X_11 ;
         s1.D21 * X_11 ;
         s2.D21 * X_21 ] + [s1.C1 zeros(size(s1.C1,1),size(s2.C1,2)); blkdiag(s1.C2, s2.C2)]

    D = [s1.D11 * X_12 ;
        s1.D21 * X_12 ;
        s2.D21 * X_22 ]
    tmp = [s1.D12 zeros(size(s1.D12,1),size(s2.D12,2)); blkdiag(s1.D22, s2.D22)]
    D[:, end-size(tmp,2)+1:end] .+= tmp

    # in case it is desired to consider both outputs
    # C = [s1.D11 * X_11 ;
    #      s2.D11 * X_21 ;
    #      s1.D21 * X_11 ;
    #      s2.D21 * X_21 ] + [blkdiag(s1.C1, s2.C1); blkdiag(s1.C2, s2.C2)]
    #
    # D = [s1.D11 * X_12 ;
    #     s2.D11 * X_22 ;
    #     s1.D21 * X_12 ;
    #     s2.D21 * X_22 ]
    #tmp = [blkdiag(s1.D12, s2.D12); blkdiag(s1.D22, s2.D22)]
    #D[:, end-size(tmp,2)+1:end] .+= tmp

    P = StateSpace(A, B, C, D, 0)
    PartionedStateSpace(P, s2.nu1, s1.ny1)
end