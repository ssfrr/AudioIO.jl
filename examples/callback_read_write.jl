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
Custom callback for read, processes passed data array
"""
function store_read(buf)
    read_size = length(buf)
    global read_position
    if read_position + read_size > length(BUFFER)
        read_size = length(BUFFER) - read_position
    end
    if read_size > 0
        BUFFER[read_position + 1 : read_position + read_size] = 
            buf[1: read_size]
        read_position += read_size
    end
end

write_position = 0
"""
Custom callback for write, returns data array
"""
function get_writeable()
    write_size = CHUNKSIZE * CHANNELS
    global write_position
    if write_position + write_size > length(BUFFER)
        write_position = length(BUFFER) - write_size
        retval = 1
    end
    start_position = write_position + 1
    write_position += write_size
    buf = BUFFER[start_position: write_position]
    buf
end

INS, OUTS = choose_input_output()

istream = AudioIO.open_read(INS, CHANNELS, SRATE, CHUNKSIZE,
                            false, FORMAT, store_read)
println("Started callback type reading device number $INS")
sleep(5)
AudioIO.Pa_CloseStream(istream.stream)

ostream = AudioIO.open_write(OUTS, CHANNELS, SRATE, CHUNKSIZE, 
                             false, FORMAT, get_writeable)
println("Started callback type writing device number $OUTS")
sleep(3)
AudioIO.Pa_CloseStream(ostream.stream)
