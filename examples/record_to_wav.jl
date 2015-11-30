# -*- coding: utf-8 -*-

# Example for Julia AudioIO module
# uses the WAV.jl package

using AudioIO
using WAV

CHUNKSIZE = 40960
FORMAT = AudioIO.paInt16
CHANNELS = 2
SRATE = 44100
RECORD_SECONDS = 20

"""
choose the devices for 2 channel IO
"""
function choose_input_output()
    devices = get_audio_devices()
    indev = -1
    outdev = -1
    for aud in devices
        println("$(aud.device_index) $(aud.name)")
        if (aud.max_input_channels == CHANNELS) & (indev == -1 )
            indev = aud.device_index
        end
        if(aud.max_output_channels == CHANNELS) & (outdev == -1)
            outdev = aud.device_index
        end
    end
    if indev == -1
        info("Appropriate input device not found.")
    elseif outdev == -1
        info("Appropriate output device not found.")
    else
        info("Using input device ", bytestring(devices[indev + 1].name), 
             ", number ", devices[indev + 1].device_index, 
             " and output device ", bytestring(devices[outdev + 1].name), 
             ", number ", devices[outdev + 1].device_index)
    end
    return indev, outdev
end

"""
read from input
"""
function record_audio(devnum, seconds)
    instream = AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE)
    bufsize = seconds * SRATE * CHANNELS
    buf = AudioIO.read(instream, bufsize)
    AudioIO.Pa_CloseStream(instream.stream)
    buf
end

"""
write to WAV file
"""
function write_as_WAV(buffer, filename="temp.WAV")
    fio = open(filename, "w")
    WAV.wavwrite(buffer, fio, Fs=SRATE*CHANNELS)
end


INS, OUTS = choose_input_output()

println("Starting recording...")
BUF = record_audio(INS, RECORD_SECONDS)
println("Finished reading from device number $INS")
println("Recording volume was $(mean(abs(BUF))*(100/16783))% of max")

write_as_WAV(BUF)
println("Finished writing to WAV file.")

