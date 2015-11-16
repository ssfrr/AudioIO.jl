# -*- coding: utf-8 -*-

#=
Testing for Julia AudioIO module
Open an input device, record 3 seconds of audio,
cube the values, then output the 3 seconds to an output device
=#


using Base.Test

using AudioIO

CHUNKSIZE = 2048
FORMAT = AudioIO.paInt16
CHANNELS = 2
SRATE = 44100
RECORD_SECONDS = 3

BUFFER = zeros(Int16, SRATE * RECORD_SECONDS * 2)

"""
choose the devices for 2 channel IO
"""
function choose_input_output()
    devices = get_audio_devices()
@test length(devices) > 0
    indev = -1
    outdev = -1
    for aud in devices
        if (aud.max_input_channels == CHANNELS) & (indev == -1)
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
@test indev >= 0  
@test outdev >= 0  
    return indev, outdev
end

"""
read from input
"""
function read_seconds!(devnum, buf = BUFFER, secs = RECORD_SECONDS)
    chunksize = Integer(length(buf) / 10)
    instream = AudioIO.Pa_AudioStream(devnum, CHANNELS, true, 
                                      SRATE, chunksize)
    read_pos = 1
    while read_pos < length(buf)
        chunk = AudioIO.read_Pa_AudioStream(instream)
        end_pos = read_pos + chunksize - 1
        buf[read_pos: end_pos] = instream.sbuffer[1:chunksize]
        read_pos = end_pos + 1
    end
@test read_pos < length(buf) + 10
end

"""
write to output
"""
function write_seconds(devnum, outbuf = BUFFER)
    chunksize = Integer(length(outbuf) / 10)
    outstream = AudioIO.Pa_AudioStream(devnum, CHANNELS, false, 
                                       SRATE, chunksize)
    write_pos = 1
    while write_pos < length(outbuf)
        end_pos = write_pos + chunksize - 1
        buffer = outbuf[write_pos: end_pos]
        write_pos = end_pos + 1
    end
@test write_pos < length(outbuf) + 10
end

INS, OUTS = choose_input_output()

read_seconds!(INS, BUFFER)
println("Finished reading")

BUFFER .^= 3
write_seconds(OUTS)
println("Finished writing")

