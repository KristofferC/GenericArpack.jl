using Test
using ArpackInJulia

@testset "macros" begin

  @testset "docs" begin
    mutable struct MyTestType
      x::Int64
      y::Float64
    end
    @test """# Fields
    ```
    x :: Int64
    y :: Float64
    ```
    """ == ArpackInJulia._output_fields_in_markdown(MyTestType)
  end

  function test_arpack_macros(;stats=nothing)
    t0 = ArpackInJulia.@jl_arpack_time
    sleep(5.0)
    ArpackInJulia.@jl_update_time(taupd, t0)
    return 5
  end
  @test test_arpack_macros()==5 # this checks with no timing information

  arpackstat = ArpackStats()
  test_arpack_macros(stats=arpackstat)
  @test arpackstat.taupd > 0

  function test_arpack_debug(x;debug=nothing)
    msglvl = ArpackInJulia.@jl_arpack_debug(mgets,0)
    if msglvl > 0
      x[1] += 1
    else
      x[1] = 0
    end
  end

  debug=ArpackDebug()

  x = ones(1)
  test_arpack_debug(x)
  @test x[1] == 0
  x = ones(1)
  test_arpack_debug(x;debug)
  @test x[1] == 0
  debug.mgets = 1
  test_arpack_debug(x;debug)
  @test x[1] == 1

  function test_arpack_debug_output(x;debug=nothing)
    msglvl = ArpackInJulia.@jl_arpack_debug(mgets,0)
    if msglvl > 0
      println(debug.logfile, "xval=", x[1])
    end
  end

  io = IOBuffer()
  debug=ArpackDebug(logfile=io)
  x[1] = 0.5
  @test_nowarn test_arpack_debug_output(x)
  @test_nowarn test_arpack_debug_output(x;debug=nothing)
  @test_nowarn test_arpack_debug_output(x;debug)
  @test String(take!(io)) == ""
  debug.mgets = 1
  @test_nowarn test_arpack_debug_output(x;debug)
  @test String(take!(io)) == "xval=0.5\n"
end


@testset "simple" begin
  @testset "dsgets" begin
    ishift = 1
    for which = [:BE,:LA,:LM,:SM,:SA]
      kev = 3
      np = 2
      ritz = [-1.0, 0.05, -0.001, 1.0, 2.0]
      bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
      pairs = Set(zip(ritz, bounds))
      shifts = [0.0, 0.0, 0.0]
      @test_nowarn ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
      @test pairs == Set(zip(ritz, bounds)) # should get the same pairs in both cases

      kev = 2
      np = 3
      ritz = [-1.5, 0.05, -0.001, 1.0, 2.0]
      bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
      shifts = [0.0, 0.0, 0.0]
      pairs = Set(zip(ritz, bounds))
      @test_nowarn ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
      @test pairs == Set(zip(ritz, bounds)) # should get the same pairs in both cases

      @test union!(Set(shifts[1:np]), ritz[np+1:end]) == Set(ritz)
      if which == :LM
        @test ritz[end] == 2.0
        @test ritz[end-1] == -1.5
      elseif which == :SA
        @test ritz[end] == -1.5 # smallest algebraic entry
        @test ritz[end-1] == -0.001
      elseif which == :SM
        @test ritz[end] == -0.001 # smallest magnitude is last
        @test ritz[end-1] == 0.05
      elseif which == :BE
        @test ritz[end] == 2.0 # largest magnitude
        @test ritz[end-1] == -1.5 # largest at other end
      elseif which == :LA
        @test ritz[end] == 2.0 # largest magnitude
        @test ritz[end-1] == 1.0 # largest at other end
      end
    end

    ishift = 0
    # in this case shifts should not really be changed.
  end
  @testset "dsconv" begin
    @test_throws ArgumentError ArpackInJulia.dsconv(6, zeros(5), ones(5), 1e-8)
    @test_nowarn ArpackInJulia.dsconv(5, zeros(5), ones(5), 1e-8)
    @test_nowarn ArpackInJulia.dsconv(5, zeros(5), ones(5), 1e-8;
                    stats=ArpackInJulia.ArpackStats())
    stats = ArpackInJulia.ArpackStats()
    @test ArpackInJulia.dsconv(15, ones(15), zeros(15), 1e-8; stats)==15
    #@test stats.tconv > 0  # we did record some time
    t1 = stats.tconv
    @test ArpackInJulia.dsconv(25, ones(25), zeros(25), 1e-8; stats)==25
    #@test stats.tconv > t1  # we did record some more time

    # TODO, add more relevant tests here.
  end

  @testset "dsortr" begin
    x = randn(10)
    # check obvious error
    @test_throws ArgumentError ArpackInJulia.dsortr(:LA, false, length(x)+1, x, zeros(0))
    @test_throws ArgumentError ArpackInJulia.dsortr(:LA, true, length(x), x, zeros(0))
    @test_nowarn ArpackInJulia.dsortr(:LA, false, length(x), x, zeros(0))
    @test issorted(x)

    x = randn(8)
    @test_nowarn ArpackInJulia.dsortr(:LA, false, length(x), x, zeros(0))
    @test issorted(x)
  end

end

@testset "dstqrb" begin
include("dstqrb.jl")
end

##
# To run, use
# using Pkg; Pkg.test("ArpackInJulia"; test_args=["arpackjll"])
#
if "arpackjll" in ARGS
  include("arpackjll.jl") # get the helpful routines to call stuff in "arpackjll"
  @testset "arpackjll" begin
    @testset "dsconv" begin
      soln = arpack_dsconv(10, ones(10), zeros(10), 1e-8)
      @test ArpackInJulia.dsconv(10, ones(10), zeros(10), 1e-8)==soln

      soln = arpack_dsconv(10, zeros(10), ones(10), 1e-8)
      @test ArpackInJulia.dsconv(10, zeros(10), ones(10), 1e-8)==soln
    end

    @testset "dsortr" begin
      #soln = arpack_dsconv(10, ones(10), zeros(10), 1e-8)
      #@test ArpackInJulia.dsconv(10, ones(10), zeros(10), 1e-8)==soln
      x = collect(9.0:-1:1)
      x1 = copy(x); x2 = copy(x)
      ArpackInJulia.dsortr(:LM, false, length(x), x1, zeros(0))
      arpack_dsortr(:LM, false, length(x), x2, zeros(0))
      @test x1==x2

      x = collect(9.0:-1:1)
      y = collect(1.0:9)
      x1 = copy(x); x2 = copy(x)
      y1 = copy(y); y2 = copy(y)
      ArpackInJulia.dsortr(:LA, true, length(x), x1, y1)
      arpack_dsortr(:LA, true, length(x), x2, y2)
      @test x1==x2
      @test y1==y2
    end

    @testset "dsgets" begin
      ishift = 1
      for which = [:BE,:LA,:LM,:SM,:SA]
        kev = 3
        np = 2
        ritz = [-1.0, 0.05, -0.001, 1.0, 2.0]
        bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
        shifts = [0.0, 0.0, 0.0]

        aritz = copy(ritz)
        abounds = copy(bounds)
        ashifts = copy(shifts)
        arpack_dsgets(ishift, which, kev, np, aritz, abounds, ashifts)
        ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
        @test ritz == aritz
        @test bounds == abounds
        @test shifts == ashifts

        kev = 2
        np = 3
        ritz = [-1.0, 0.05, -0.001, 1.0, 2.0]
        bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
        shifts = [0.0, 0.0, 0.0]

        aritz = copy(ritz)
        abounds = copy(bounds)
        ashifts = copy(shifts)
        arpack_dsgets(ishift, which, kev, np, aritz, abounds, ashifts)
        ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
        @test ritz == aritz
        @test bounds == abounds
        @test shifts == ashifts

        kev = 5
        np = 0
        ritz = [-1.0, 0.05, -0.001, 1.0, 2.0]
        bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
        shifts = [0.0, 0.0, 0.0]

        aritz = copy(ritz)
        abounds = copy(bounds)
        ashifts = copy(shifts)
        arpack_dsgets(ishift, which, kev, np, aritz, abounds, ashifts)
        ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
        @test ritz == aritz
        @test bounds == abounds
        @test shifts == ashifts
      end

      ishift=0
      for which = [:BE,:LA,:LM,:SM,:SA]
        kev = 2
        np = 3
        ritz = [-1.0, 0.05, -0.001, 1.0, 2.0]
        bounds = [0.0, 0.01, 0.00001, 2.0, 0.5]
        shifts = randn(3)
        orig_shifts = copy(shifts)

        aritz = copy(ritz)
        abounds = copy(bounds)
        ashifts = copy(shifts)
        arpack_dsgets(ishift, which, kev, np, aritz, abounds, ashifts)
        ArpackInJulia.dsgets(ishift, which, kev, np, ritz, bounds, shifts)
        @test ritz == aritz
        @test bounds == abounds
        @test shifts == ashifts == orig_shifts # should be unchanged for ishift=0
      end
    end
    @testset "dstqrb" begin
      include("dstqrb-compare.jl")
    end
  end
end

##
function all_permutations(v::Vector{Float64};
    all::Vector{Vector{Float64}}=Vector{Vector{Float64}}(),
    prefix::Vector{Float64}=zeros(0))

  if length(v) == 0
    push!(all, prefix)
  end

  for i in eachindex(v)
    all_permutations(deleteat!(copy(v), i); prefix=push!(copy(prefix), v[i]), all)
  end
  return all
end
##

if "full" in ARGS
  @testset "dsortr" begin
    for range in [0:0.0,0:1.0,-1:1.0,-2:1.0,-2:2.0,-2:3.0,-3:3.0,-4:3.0,-4:4.0,-4:5.0]
      X = all_permutations(collect(range))
      for x in X
        y = copy(x)
        @test_nowarn ArpackInJulia.dsortr(:LA, false, length(y), y, zeros(0))
        @test issorted(y)

        y = copy(x)
        @test_nowarn ArpackInJulia.dsortr(:LM, false, length(y), y, zeros(0))
        @test issorted(y, by=abs)

        y = copy(x)
        @test_nowarn ArpackInJulia.dsortr(:SM, false, length(y), y, zeros(0))
        @test issorted(y, by=abs, rev=true)

        y = copy(x)
        @test_nowarn ArpackInJulia.dsortr(:SA, false, length(y), y, zeros(0))
        @test issorted(y, rev=true)
      end
    end
  end
end
