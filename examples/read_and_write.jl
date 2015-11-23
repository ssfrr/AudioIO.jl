# -*- coding: utf-8 -*-

# Examples for Julia AudioIO module

using AudioIO

CHUNKSIZE = 40960
FORMAT = AudioIO.paInt16
CALLBACK_DATATYPE = AudioIO.PaSampleFormat_to_T(FORMAT)
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

read_position = 0
function read_callback(input::Ptr{Void}, output::Ptr{Void}, 
                  frameCount::Culong, 
                  timeInfo::Ptr{AudioIO.CCallbackTimeInfo}, 
                  sflags::Culong, udata::Ptr{Void})
    global read_position
    buf = pointer_to_array(Ptr{CALLBACK_DATATYPE}(input), 
                           (frameCount * CHANNELS, ))
    read_size = length(buf)
    if read_position + read_size > length(BUFFER)
        read_size = length(BUFFER) - read_position
    end
    if read_size > 0
        BUFFER[read_position + 1 : read_position + read_size] = 
            buf[1: read_size]
        read_position += read_size
    end
    0
end

write_position = 0
function write_callback(input::Ptr{Void}, output::Ptr{Void}, 
                  frameCount::Culong, 
                  timeInfo::Ptr{AudioIO.CCallbackTimeInfo}, 
                  sflags::Culong, udata::Ptr{Void})
    global write_position
    write_size = frameCount * CHANNELS
    if write_position + write_size > length(BUFFER)
        write_position = length(BUFFER) - write_size
    end
    start_position = write_position + 1
    write_position += write_size
    buf = BUFFER[start_position: write_position]
    ccall(:memcpy, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint), 
          output, buf, write_size * 2)
    0
end

const r_c_callback = cfunction(read_callback, Cint, (Ptr{Void}, 
                               Ptr{Void}, 
                               Culong, Ptr{AudioIO.CCallbackTimeInfo}, 
                               Culong, Ptr{Void}))

const w_c_callback = cfunction(write_callback, Cint, (Ptr{Void}, 
                               Ptr{Void}, 
                               Culong, Ptr{AudioIO.CCallbackTimeInfo}, 
                               Culong, Ptr{Void}))

"""
read using callback
"""
function start_read_callback(devnum)
    rstream = AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE,
                                false, FORMAT, r_c_callback)
end

"""
write using callback
"""
function start_write_callback(devnum)
    wstream = AudioIO.open_write(devnum, CHANNELS, SRATE, CHUNKSIZE, 
                                 false, FORMAT, w_c_callback)
end

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

istream = start_read_callback(INS)
println("Started callback type reading device number $INS")
sleep(3)
AudioIO.Pa_CloseStream(istream.stream)

BUFFER = make_note_buffer(88.0, 0.4, 3, SRATE)
ostream = start_write_callback(OUTS)
println("Started callback type writing device number $OUTS")
sleep(3)
AudioIO.Pa_CloseStream(ostream.stream)

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
