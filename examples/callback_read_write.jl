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

read_position = 0
"""
Custom callback for read
Must process frameCount frames from the input buffer
Return 0 to ask for more data, 1 to ask for no more callbacks
"""
function store_read(input::Ptr{Void}, output::Ptr{Void}, 
                  frameCount::Culong, 
                  timeInfo::Ptr{AudioIO.CCallbackTimeInfo}, 
                  sflags::Culong, udata::Ptr{Void})
    retval = 0
    buf = pointer_to_array(Ptr{CALLBACK_DATATYPE}(input), 
                           (frameCount * CHANNELS, ))
    read_size = length(buf)
    global read_position
    if read_position + read_size > length(BUFFER)
        read_size = length(BUFFER) - read_position
    end
    if read_size > 0
        BUFFER[read_position + 1 : read_position + read_size] = 
            buf[1: read_size]
        read_position += read_size
    else
        retval = 1
    end
    Cint(retval)
end

write_position = 0
"""
Custom callback for write
Must write frameCount frames to the output buffer
Return 0 to continue to write data, 1 to ask for no more callbacks
"""
function get_writeable(input::Ptr{Void}, output::Ptr{Void}, 
                  frameCount::Culong, 
                  timeInfo::Ptr{AudioIO.CCallbackTimeInfo}, 
                  sflags::Culong, udata::Ptr{Void})
    retval = 0
    write_size = frameCount * CHANNELS
    global write_position
    if write_position + write_size > length(BUFFER)
        write_position = length(BUFFER) - write_size
        retval = 1
    end
    start_position = write_position + 1
    write_position += write_size
    buf = BUFFER[start_position: write_position]
    ccall(:memcpy, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint), 
          output, buf, length(buf) * sizeof(buf[1]))
    Cint(retval)   
end

const rcallback = cfunction(store_read, Cint, (Ptr{Void}, 
                               Ptr{Void}, 
                               Culong, Ptr{AudioIO.CCallbackTimeInfo}, 
                               Culong, Ptr{Void}))

const wcallback = cfunction(get_writeable, Cint, (Ptr{Void}, 
                               Ptr{Void}, 
                               Culong, Ptr{AudioIO.CCallbackTimeInfo}, 
                               Culong, Ptr{Void}))

"""
Start read using callback
"""
function start_read_callback(devnum)
    rstream = AudioIO.open_read(devnum, CHANNELS, SRATE, CHUNKSIZE,
                                false, FORMAT, rcallback)
end

"""
Start write using callback
"""
function start_write_callback(devnum)
    wstream = AudioIO.open_write(devnum, CHANNELS, SRATE, CHUNKSIZE, 
                                 false, FORMAT, wcallback)
end

INS, OUTS = choose_input_output()

istream = start_read_callback(INS)
println("Started callback type reading device number $INS")
sleep(5)
AudioIO.Pa_CloseStream(istream.stream)

ostream = start_write_callback(OUTS)
println("Started callback type writing device number $OUTS")
sleep(3)
AudioIO.Pa_CloseStream(ostream.stream)
