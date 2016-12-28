# -*- coding: utf-8 -*-

# Examples for Julia AudioIO module

# display relative (not absolute) dB of bass, mid, treble bands

using AudioIO, DSP


"""
Custom callback for read, processes passed data array
"""
function process_read(buf)
    fchunk = map(Float64, buf)
    pgram = welch_pgram(fchunk, 4096, 0, fs=SRATE*CHANNELS)
    pxx = power(pgram)
    frqs = freq(pgram)
    bass = log(sum(abs(pxx[(frqs .<= 640.0) & (frqs .> 100.0)])))
    midrange = log(sum(abs(pxx[(frqs .<= 5120.0) & (frqs .> 640.0)])))
    treble = log(sum(abs(pxx[(frqs .<= 20480.0) & (frqs .> 5120.0)])))
    println("bass $bass, midrange $midrange, treble $treble")
end

CHUNKSIZE = 40960
FORMAT = AudioIO.paInt16
CHANNELS = Cint(2)
SRATE = 44100
istream = AudioIO.open_read(Cint(0), CHANNELS, SRATE, CHUNKSIZE,
                            false, FORMAT, process_read)
println("Starting callback type reading, control-C to stop")

while true
    sleep(20)
end
