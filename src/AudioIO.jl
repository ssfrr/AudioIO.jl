module AudioIO

# export the basic API
export play!, stop!, get_audio_devices

# default stream used when none is given
_stream = nothing

################## Types ####################

typealias AudioSample Float32
# A frame of audio, possibly multi-channel
typealias AudioBuf Array{AudioSample}

# A stream of audio (for instance that writes to hardware). All AudioStream
# subtypes should have a root and info field
abstract AudioStream
samplerate(str::AudioStream) = str.info.sample_rate
bufsize(str::AudioStream) = str.info.buf_size

# An audio interface is usually a physical sound card, but could
# be anything you'd want to connect a stream to
abstract AudioInterface

# Info about the hardware device
type DeviceInfo
    sample_rate::Float32
    buf_size::Integer
end

# Get binary dependencies loaded from BinDeps
include( "../deps/deps.jl")
include("nodes.jl")
include("portaudio.jl")
include("sndfile.jl")

function play!(node::AudioNode, stream=_stream)
    global _stream
    if is(_stream, nothing)
        _stream = PortAudioStream()
    end
    stream.root = node
end

function stop!(stream=_stream)
    stream.root = NullNode()
end

end # module AudioIO
