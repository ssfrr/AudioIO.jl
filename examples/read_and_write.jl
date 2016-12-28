# -*- coding: utf-8 -*-

# Examples for Julia AudioIO module

using AudioIO

CHUNKSIZE = 40960
FORMAT = AudioIO.paInt16
CHANNELS = 2
SRATE = 44100
RECORD_SECONDS = 3

BUFFER = zeros(Int16, SRATE * RECORD_SECONDS * 4)
BUFSIZE = SRATE * RECORD_SECONDS

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
function read_blocking(devnum, buffer)
    instream = AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE)
    buf = AudioIO.read(instream, BUFSIZE)
    buflen = length(buf)
    buffer[1: buflen] = buf[1: buflen]
    AudioIO.Pa_CloseStream(instream.stream)
end

"""
write to output
"""
function write_blocking(devnum, buffer)
    outstream = AudioIO.open_write(devnum, CHANNELS, SRATE, CHUNKSIZE)
    AudioIO.write(outstream, buffer)
    AudioIO.Pa_CloseStream(outstream.stream)
end

"""
Create a string of numbers representing a sinewave audio tone
"""
function make_note_buffer(frequency, amplitude, duration, srate)
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
    tone
end

"""
Write a note to output device
"""
function play_note(frequency, amplitude, duration, srate, ostream)
    note = make_note_buffer(frequency, amplitude, duration, srate)
    AudioIO.write(ostream, note)
end

INS, OUTS = choose_input_output()

read_blocking(INS, BUFFER)
println("Finished blocking type reading device number $INS")
println("Recording volume is $(mean(abs(BUFFER))*(100/16783))% of max")
sleep(2)

write_blocking(OUTS, BUFFER)
println("Finished blocking type writing device number $OUTS")

outstream = AudioIO.open_write(OUTS, CHANNELS, SRATE, CHUNKSIZE)
# play the C major scale
scale = [130.8, 146.8, 164.8, 174.6, 195.0, 220.0, 246.9, 261.6]
for note in scale
    play_note(note, 0.1, 0.75, SRATE, outstream)
end
# up an octave
for note in scale[2:8]
    play_note(2*note, 0.1, 0.75, SRATE, outstream)
end
