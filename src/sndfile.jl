export af_open, FilePlayer, rewind, samplerate

const SFM_READ = int32(0x10)
const SFM_WRITE = int32(0x20)

const SF_FORMAT_WAV =  0x010000
const SF_FORMAT_FLAC = 0x170000
const SF_FORMAT_OGG =  0x200060

const SF_FORMAT_PCM_S8 = 0x0001 # Signed 8  bit data
const SF_FORMAT_PCM_16 = 0x0002 # Signed 16 bit data
const SF_FORMAT_PCM_24 = 0x0003 # Signed 24 bit data
const SF_FORMAT_PCM_32 = 0x0004 # Signed 32 bit data

const SF_SEEK_SET = 0
const SF_SEEK_CUR = 1
const SF_SEEK_END = 2

const EXT_TO_FORMAT = [
    ".wav" => SF_FORMAT_WAV,
    ".flac" => SF_FORMAT_FLAC
]

type SF_INFO
    frames::Int64
    samplerate::Int32
    channels::Int32
    format::Int32
    sections::Int32
    seekable::Int32

    function SF_INFO(frames::Integer, samplerate::Integer, channels::Integer,
                     format::Integer, sections::Integer, seekable::Integer)
        new(int64(frames), int32(samplerate), int32(channels), int32(format),
            int32(sections), int32(seekable))
    end
end

type AudioFile
    filePtr::Ptr{Void}
    sfinfo::SF_INFO
end

samplerate(f::AudioFile) = f.sfinfo.samplerate

# AudioIO.open is part of the public API, but is not exported so that it
# doesn't conflict with Base.open
function open(path::String, mode::String = "r",
            sampleRate::Integer = 44100, channels::Integer = 1,
            format::Integer = 0)
    @assert channels <= 2

    sfinfo = SF_INFO(0, 0, 0, 0, 0, 0)
    file_mode = SFM_READ

    if mode == "w"
        file_mode = SFM_WRITE
        sfinfo.samplerate = sampleRate
        sfinfo.channels = channels
        if format == 0
            _, ext = splitext(path)
            sfinfo.format = EXT_TO_FORMAT[ext] | SF_FORMAT_PCM_16
        else
            sfinfo.format = format
        end
    end

    filePtr = ccall((:sf_open, libsndfile), Ptr{Void},
                    (Ptr{Uint8}, Int32, Ptr{SF_INFO}),
                    path, file_mode, &sfinfo)

    if filePtr == C_NULL
        errmsg = ccall((:sf_strerror, libsndfile), Ptr{Uint8}, (Ptr{Void},), filePtr)
        error(bytestring(errmsg))
    end

    return AudioFile(filePtr, sfinfo)
end

function Base.close(file::AudioFile)
    err = ccall((:sf_close, libsndfile), Int32, (Ptr{Void},), file.filePtr)
    if err != 0
        error("Failed to close file")
    end
end

function open(f::Function, args...)
    file = AudioIO.open(args...)
    try
        f(file)
    finally
        close(file)
    end
end

function af_open(args...)
    warn("af_open is deprecated, please use AudioIO.open instead")
    AudioIO.open(args...)
end

# TODO: we should implement a general read(node::AudioNode) that pulls data
# through an arbitrary render chain and returns the result as a vector
function Base.read(file::AudioFile, nframes::Integer, dtype::Type)
    @assert file.sfinfo.channels <= 2
    # the data comes in interleaved
    arr = zeros(dtype, file.sfinfo.channels, nframes)

    if dtype == Int16
        nread = ccall((:sf_readf_short, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Int16}, Int64),
                        file.filePtr, arr, nframes)
    elseif dtype == Int32
        nread = ccall((:sf_readf_int, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Int32}, Int64),
                        file.filePtr, arr, nframes)
    elseif dtype == Float32
        nread = ccall((:sf_readf_float, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Float32}, Int64),
                        file.filePtr, arr, nframes)
    elseif dtype == Float64
        nread = ccall((:sf_readf_double, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Float64}, Int64),
                        file.filePtr, arr, nframes)
    end

    return arr[:, 1:nread]'
end

Base.read(file::AudioFile, dtype::Type) = Base.read(file, file.sfinfo.frames, dtype)
Base.read(file::AudioFile, nframes::Integer) = Base.read(file, nframes, Int16)
Base.read(file::AudioFile) = Base.read(file, Int16)

function Base.write{T}(file::AudioFile, frames::Array{T})
    @assert file.sfinfo.channels <= 2
    nframes = int(length(frames) / file.sfinfo.channels)

    if T == Int16
        return ccall((:sf_writef_short, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Int16}, Int64),
                        file.filePtr, frames, nframes)
    elseif T == Int32
        return ccall((:sf_writef_int, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Int32}, Int64),
                        file.filePtr, frames, nframes)
    elseif T == Float32
        return ccall((:sf_writef_float, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Float32}, Int64),
                        file.filePtr, frames, nframes)
    elseif T == Float64
        return ccall((:sf_writef_double, libsndfile), Int64,
                        (Ptr{Void}, Ptr{Float64}, Int64),
                        file.filePtr, frames, nframes)
    end
end

function Base.seek(file::AudioFile, offset::Integer, whence::Integer)
    new_offset = ccall((:sf_seek, libsndfile), Int64,
        (Ptr{Void}, Int64, Int32), file.filePtr, offset, whence)

    if new_offset < 0
        error("Could not seek to $(offset) in file")
    end

    new_offset
end

# Some convenience methods for easily navigating through a sound file
Base.seek(file::AudioFile, offset::Integer) = seek(file, offset, SF_SEEK_SET)
rewind(file::AudioFile) = seek(file, 0, SF_SEEK_SET)

immutable FilePlayer <: AudioNode
    file::AudioFile
end

FilePlayer(fname::String) = FilePlayer(AudioIO.open(fname))
    

function pull(node::FilePlayer, sf, offset, n, buf=Float32[])
    # Ignore the offset and keep reading the file
    # TODO: resample if necessary

    # Keep reading data from the file until the output buffer is full, but stop
    # as soon as no more data can be read from the file
    audio = Array(AudioSample, 0, node.file.sfinfo.channels)
    while true
        read_audio = read(node.file, n-size(audio, 1), AudioSample)
        audio = vcat(audio, read_audio)
        if size(audio, 1) >= n || size(read_audio, 1) <= 0
            break
        end
    end

    # if the file is stereo, mix the two channels together
    if node.file.sfinfo.channels == 2
        audio = (audio[:, 1] / 2) + (audio[:, 2] / 2)
    end

    if length(audio) < n
        resize!(audio, n)
    end
    audio
end

