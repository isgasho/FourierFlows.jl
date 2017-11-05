include("./setup_eddywave.jl")

# Basics
nkw = 8
nx = 256
Lx = 2π*100e3*nkw

plotpath = "./plots"
plotname = "strongsixthorder"

alpha    = 1         # Frequency parameter
ep       = 2e-1      # Wave amplitude
Ro       = 5e-2      # Eddy Rossby number
Reddy    = Lx/10     # Eddy radius


# Setup
ew = EddyWave(Lx, alpha, ep, Ro, Reddy; nkw=nkw, dtfrac=5e-3, nsubperiods=1,
  nnu0=6, nnu1=6, nu0=1e22, nu1=1e6) 
  #nnu0=4, nnu1=6, nu0=1e14, nu1=1e6)
  
prob, diags = eddywavesetup(nx, ew, perturbwavefield=false)
etot, e0, e1 = diags[1], diags[2], diags[3]


# Output
getsolr(prob) = prob.vars.solr
getsolc(prob) = prob.vars.solc
getpsiw(prob) = wave_induced_psi(ew.sigma, prob)
getuw(prob)   = wave_induced_uv(ew.sigma, prob)[1]
getvw(prob)   = wave_induced_uv(ew.sigma, prob)[2]

filename = @sprintf("./data/%s_%df_nx%d_ep%02d_Ro%02d_nkw%02d.jld2",
  plotname, 100*ew.sigma/ew.f, nx, 100ep, 100Ro, ew.nkw)

outs = [
  Output("solr", getsolr,  prob, filename),
  Output("solc", getsolc,  prob, filename),
  Output("Q",    mode0apv, prob, filename),
  Output("w",    mode1w,   prob, filename),
  Output("uw",   getuw,    prob, filename),
  Output("vw",   getvw,    prob, filename)
]



# Plotting
fig, axs = subplots(ncols=2, nrows=2, figsize=(8, 8)) 
xr, yr = prob.grid.X/Reddy, prob.grid.Y/Reddy


# Run
startwalltime = time()
while prob.step < ew.nsteps

  stepforward!(prob, diags; nsteps=ew.nsubs)
  TwoModeBoussinesq.updatevars!(prob)

  walltime = (time()-startwalltime)/60

  log1 = @sprintf(
    "step: %04d, t: %d, CFL: %.2f, max Ro: %.4f, ", 
    prob.step, prob.t/ew.twave, CFL(prob, prob.ts.dt), 
    maximum(abs.(prob.vars.Z))/ew.f)

  log2 = @sprintf(
    "e0: %.3f, e1: %.3f, etot: %.6f, wall: %.2f min",
    e0.value/e0.data[1], e1.value/e1.data[1], etot.value/etot.data[1],
    walltime)

  println(log1*log2)

  plotmsg1 = @sprintf(
    "\$t=%02d\$ wave periods, \$E_0=%.3f\$, ",
    round(Int, prob.t/ew.twave), e0.value/e0.data[1])
    
  plotmsg2 = @sprintf(
    "\$E_1=%.3f\$, \$E_{\\mathrm{tot}}=%.6f\$",
    e1.value/e1.data[1], etot.value/etot.data[1])

  savename = @sprintf("%s_nx%d_%02df_ep%02d_Ro%02d_%06d.png", 
    joinpath(plotpath, plotname), nx, floor(Int, 100ew.sigma/ew.f), 
    floor(Int, 100*ew.ep), floor(Int, 100*ew.Ro), prob.step)

  makeplot!(axs, prob, ew, xr, yr, savename; 
    message=plotmsg1*plotmsg2, save=true, eddylim=nothing)

end