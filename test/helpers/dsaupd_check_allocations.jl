# https://discourse.julialang.org/t/memory-allocation-and-profile/47573/5
using ArpackInJulia
using LinearAlgebra
function eigrun(op,ido, ::Val{BMAT}, n, which, nev, tol, resid, ncv, V, ldv, iparam, ipntr, workd, workl, lworkl, info_initv, state) where BMAT 
  niter = 0 
  while ido[] != 99
    ArpackInJulia.dsaupd!(ido, Val(BMAT), n, which, nev, tol, resid, ncv, V, ldv, iparam,
      ipntr, workd, workl, lworkl, info_initv;
      state 
    )
    if ido[] == 1 || ido[] == -1
      niter += 1
      ArpackInJulia._i_do_now_opx_1!(op, ipntr, workd, n)
    elseif ido[] == 99
      break
    else
      @error("this only supports standard eigenvalue problems")
    end 
  end
  return niter
end 

op = ArpackInJulia.ArpackSimpleOp(Diagonal(1.0:10^3))
nev = 6
ido = Ref{Int}(0)
bmat = :I
n = size(op.A,1)
which = :LM
tol = 0.0 # just use the default
resid = zeros(n)
ncv = min(2nev, n-1)
V = zeros(n,ncv)
ldv = n
mode = 1 
iparam = zeros(Int,11)
iparam[1] = 1
#iparam[3] = 300 # max iteration
iparam[3] = 300 # 
iparam[4] = 1
iparam[7] = mode 
ipntr = zeros(Int,11)
workd = zeros(n,3)
lworkl = ncv*ncv + 8*ncv
workl = zeros(lworkl)

info_initv = 0

# Note that we cannot run two sequences at once and check them where we start a whole
# second arpack call because of the expected Arpack state. 
state = ArpackInJulia.ArpackState{Float64}()


eigrun(op, ido, Val(bmat), n, which, nev, tol, resid, ncv, V, ldv, iparam, ipntr, workd, workl, lworkl, info_initv, state);

# reset state
state = ArpackInJulia.ArpackState{Float64}()
ido[] = 0 

# rest profiling after compile
using Profile
Profile.clear_malloc_data()

eigrun(op, ido, Val(bmat), n, which, nev, tol, resid, ncv, V, ldv, iparam, ipntr, workd, workl, lworkl, info_initv, state);

exit()
##
file = @__FILE__
procinfo = run(`/Applications/Julia-1.7.app/Contents/Resources/julia/bin/julia --project=$(homedir())/Dropbox/dev/ArpackInJulia --track-allocation=user $file`)
##
include("allocations.jl")
show_allocations("."; pid=76359)