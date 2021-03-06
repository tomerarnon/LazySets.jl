for N in [Float64, Rational{Int}, Float32]
    # normal constructor
    a = ones(N, 3)
    hp = Hyperplane(a, N(5))

    # dimension
    @test dim(hp) == 3

    # support vector and membership function
    function test_svec(hp)
        d1 = copy(hp.a)
        @test σ(d1, hp) ∈ hp
        @test σ(N(2) * d1, hp) ∈ hp
        d2 = N[1, 0, 0]
        @test_throws ErrorException σ(d2, hp)
        d3 = N[1, 1, 2]
        @test_throws ErrorException σ(d3, hp)
        d4 = zeros(N, 3)
        @test σ(d4, hp) ∈ hp
    end
    # tests 1
    a = ones(N, 3)
    test_svec(Hyperplane(a, N(5)))
    # tests 2
    a = zeros(N, 3); a[3] = N(1)
    test_svec(Hyperplane(a, N(5)))

    # an_element function and membership function
    @test an_element(hp) ∈ hp
end
