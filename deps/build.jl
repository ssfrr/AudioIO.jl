using BinDeps

@BinDeps.setup

ENV["JULIA_ROOT"] = abspath(JULIA_HOME, "../../")

libportaudio = library_dependency("libportaudio")
libsndfile = library_dependency("libsndfile")

# TODO: add other providers with correct names
provides(AptGet, "portaudio19-dev", libportaudio)
provides(AptGet, "libsndfile1-dev", libsndfile)
provides(Pacman, "portaudio", libportaudio)
provides(Pacman, "libsndfile", libsndfile)

@static if is_apple()
  if Pkg.installed("Homebrew") === nothing
    error("Homebrew package not installed, please run Pkg.add(\"Homebrew\")")
  end

  using Homebrew
  provides(Homebrew.HB, "portaudio", libportaudio)
  provides(Homebrew.HB, "libsndfile", libsndfile)
end

@static if is_windows()
  if Pkg.installed("WinRPM") === nothing
    error("WinRPM package not installed, please run Pkg.add(\"WinRPM\")")
  end
  using WinRPM
  provides(WinRPM.RPM, "libportaudio2", libportaudio, os = :Windows)
  provides(WinRPM.RPM, "libsndfile1", libsndfile, os = :Windows)
end

@BinDeps.install Dict(
  :libportaudio => :libportaudio,
  :libsndfile => :libsndfile
)
