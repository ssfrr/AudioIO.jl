# -*- coding: utf-8 -*-

# Examples for Julia AudioIO module

using AudioIO

CHUNKSIZE = 40960
FORMAT = AudioIO.paInt16
CHANNELS = 2
SRATE = 44100
RECORD_SECONDS = 3

BUFFER = zeros(Int16, SRATE * RECORD_SECONDS)
BUFSIZE = length(BUFFER)

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
function read_blocking(devnum)
    instream = AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE)
    BUFFER = AudioIO.read(instream, BUFSIZE)
    AudioIO.Pa_CloseStream(instream.stream)
end

"""
write to output
"""
function write_blocking(devnum)
    outstream = AudioIO.open_write(devnum, CHANNELS, SRATE, CHUNKSIZE)
    AudioIO.write(outstream, BUFFER)
    AudioIO.Pa_CloseStream(outstream.stream)
end

"""
read callback function
"""
read_position = 0
write_position = 0
function rcallback(buf)
    read_size = length(buf)
    if read_position + read_size > length(buffer)
        read_size = length(buffer) - read_position
    end
    if read_size > 1
        BUFFER[read_position + 1 : read_position + read_size] = 
            buf[1: read_size]
        read_position += read_size
    end
    0
end
    
"""
write callback function
"""
function wcallback(buf)
    write_size = CHUNKSIZE * CHANNELS
    if write_position + write_size > length(buffer)
        write_size = length(buffer) - write_position
    end
    if write_size < 2
       return Void
    end
    start_position = write_position + 1
    write_position += write_size
    buf = BUFFER[start_position: write_position]
end

"""
read using callback
"""
function start_read_callback(devnum)
    AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE,
                      false, FORMAT,
                      AudioIO.make_c_callback(rcallback, FORMAT))
end

"""
write using callback
"""
function start_write_callback(devnum)
    AudioIO.open_write(devnum, CHANNELS, SRATE, CHUNKSIZE, 
                       false, FORMAT,
                       AudioIO.make_c_callback(wcallback, FORMAT))
end

function play_note(frequency, amplitude, duration, srate, ostream)
    N = round(Int, srate / frequency)
    T = round(Int, frequency * duration)  # repeat for T cycles
    dt = 1.0 / srate
    tone = zeros(Int16, (N + N) * T)
    idx = 1
    while idx < (N + N) * T
        tone[idx] = round(Int, amplitude * sin(2 * pi * frequency * 
                                idx * dt) * 32767.0)
        tone[idx + 1] = tone[idx]
        idx += 2
    end
    AudioIO.write(ostream, tone)
end

INS, OUTS = choose_input_output()

read_blocking(INS)
println("Finished blocking type reading device number $INS")
sleep(3)
write_blocking(OUTS)
println("Finished blocking type writing device number $OUTS")

start_read_callback(INS)
println("Started callback type reading device number $INS")
sleep(3)
ostream = start_write_callback(OUTS)
println("Started callback type writing device number $OUTS")
sleep(3)
AudioIO.Pa_CloseStream(ostream.stream)

outstream = AudioIO.open_write(OUTS, CHANNELS, SRATE, CHUNKSIZE)

# play the C major scale
scale = [130.8, 146.8, 164.8, 174.6, 195.0, 220.0, 246.9, 261.6]
for note in scale
    play_note(note, 0.5, 0.75, SRATE, outstream)
end

# up an octave
for note in scale[2:8]
    play_note(2*note, 0.5, 0.75, SRATE, outstream)
end
