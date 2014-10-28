typealias AudioSample Float32
abstract AudioNode

import Base: *, +

export SinOsc, NullNode, Mixer, AudioMixer, WhiteNoise, Gain,
       LinRamp, pull, SquareOsc, TriangleOsc

type sampleat end

# pull n samples from a node
#
# Args:
#   offset: start from this sample
#   n: number of samples to draw
#   node: AudioNode to draw from
#   buf: (optional) buffer to fill
# Returns: A Array{Float32} of size n
function pull(node::AudioNode, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end
    i = offset
    j = 1
    @inbounds while n >= j
        # draw ith sample at sf sample frequency from node
        buf[j] = sampleat(node, sf, i)
        i += 1
        j += 1
    end
    return buf
end

# Nodes

# Null node
immutable NullNode <: AudioNode end

sampleat(::NullNode, sf, i) = zero(Float32)
pull(::NullNode, sf, offset, n, buf=Float32[]) =
    zeros(Float32, n)

*(in1::NullNode, in2::NullNode) = in1
*(in1::AudioNode, in2::NullNode) = in2
*(in1::NullNode, in2::AudioNode) = in1

+(in1::NullNode, in2::NullNode) = in1
+(in1::AudioNode, in2::NullNode) = in1
+(in1::NullNode, in2::AudioNode) = in2


# White noise
immutable WhiteNoise <: AudioNode end

sampleat(::WhiteNoise, sf, i) = rand(Float32) * 2.0f0 - 1.0f0


# Sine wave
immutable SinOsc <: AudioNode
    freq::Float32
end

sampleat(osc::SinOsc, sf, i) = sin(i * osc.freq * 2pi / sf)

function pull(osc::SinOsc, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end

    i = 1
    j = float32(offset)
    coeff = float32(osc.freq * 2pi / sf)
    @inbounds while i <= n
        buf[i] = sin(j*coeff)
        i += 1
        j += 1.0f0
    end
    buf
end


# Square wave
immutable SquareOsc <: AudioNode
    freq::Float32
end

sampleat(osc::SquareOsc, sf, i) =
    (floor(2 * i * osc.freq / sf) % 2 == 0) ? 1 : -1

function pull(sq::SquareOsc, sf, offset, n, buf=Float32[])
    i = 1
    j = offset
    steplen = sf / sq.freq / 2
    v = j % 2 == 0 ? -1.0f0 : 1.0f0
    toggle = j % steplen
    togglei = int(toggle)

    while i <= n
        if i >= togglei
            v = -v
            toggle = toggle + steplen
            togglei = int(toggle)
        end
        @inbounds buf[i] = v
        i += 1
    end
    buf
end


# Saw tooth wave
immutable TriangleOsc <: AudioNode
    freq::Float32
    peakoffset::Float32
end

function sampleat(osc::TriangleOsc, sf, i)
    # where x reaches 1.
    slope1 = 1 / osc.peakoffset
    x0 = 2 / slope1
    x = (i / sf * osc.freq) - floor(i / sf * osc.freq)
    if x < x0
        x * slope1 - 1 # Uphill
    else
        1 - 2 * (x - x0) / (1 - x0) # Downhill
    end
end


# Mixer
immutable Mixer{n} <: AudioNode
    children::NTuple{n, AudioNode}
end

Mixer(nodes...) =
    Mixer{length(nodes)}(nodes)

Mixer(mixer::Mixer, nodes...) = # Flatten on concat
    Mixer{length(mixer.nodes) + length(nodes)}(
        tuple(mixer.nodes..., nodes...)
    )

const AudioMixer = Mixer
AudioMixer(nodes::Vector{AudioNode}) = Mixer(tuple(nodes...))

+(in1::AudioNode, in2::AudioNode) = Mixer(in1, in2)

# Provided for completenesss, never used
# Unroll upto Mixer{10} for speed
for n=2:10
    method = :(sampleat(mixer::Mixer{$n}, sf, i) = nothing)
    method.args[2] =
        Expr(:call, :+,
             [:(sampleat(mixer.children[$i], sf, i)) for i in 1:n]...)
    eval(method)
end
sampleat(m::Mixer, sf, i) = map(n->sampleat(n, sf, i), m.children)

# Specialized pull for Mixer
pull(node::Mixer{0}, sf, offset, n, buf=Float32[]) =
    pull(NullNode(), sf, offset, n, buf)
pull(node::Mixer{1}, sf, offset, n, buf=Float32[]) =
    pull(node.children[1], sf, offset, n, buf)

function pull{m}(node::Mixer{m}, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end
    fill!(buf, 0)
    pull(node.children[1], sf, offset, n, buf)
    k = 2
    tmp = Float32[]
    @inbounds while m >= k
        pull(node.children[k], sf, offset, n, tmp)
        if length(tmp) != n BoundsError() end
        i = 1
        while n >= i
            buf[i] += tmp[i]
            i += 1
        end
        k += 1
    end
    return buf
end


# Gain
immutable Gain{T <: Union(Float32, AudioNode)} <: AudioNode
    gain::T
    input::AudioNode
end

sampleat(node::Gain{Float32}, sf, i) =
    node.gain * sampleat(node.input, sf, i)

function pull(node::Gain{Float32}, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end
    i = 1
    pull(node.input, sf, offset, n, buf)
    scale!(buf, node.gain)
    return buf
end

sampleat{T <: AudioNode}(node::Gain{T}, sf, i) =
    sampleat(node.gain, sf, i) * sampleat(node.input, sf, i)

function pull{T<:AudioNode}(node::Gain{T}, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end
    i = 1
    pull(node.input, sf, offset, n, buf)
    gain = pull(node.gain, sf, offset, n)

    broadcast!(*, buf, gain, buf)
    buf
end

(*)(x::Real, input::AudioNode) = Gain(float32(x), input)
(*)(input::AudioNode, x::Real) = Gain(float32(x), input)
(*)(input::AudioNode, x::AudioNode) = Gain(x, input)


# Time offset by some seconds
immutable TimeOffset{T <:AudioNode} <: AudioNode
    seconds::Float32
    input::T
end

sampleat(off::TimeOffset, sf, i) =
    sampleat(off.input, sf, i+off.offset*sf)


# Amplitude offset
immutable AmpOffset{T <:AudioNode} <: AudioNode
    amplitude::Float32
    input::T
end
const Offset = AmpOffset

function pull(node::AmpOffset, sf, offset, n, buf=Float32[])
    if length(buf) != n
        resize!(buf, n)
    end
    i = 1
    pull(node.input, sf, offset, n, buf)
    @inbounds while i <= n
        buf[i] += node.amplitude
        i += 1
    end
    return buf
end

+(x::Real, a::AudioNode) = AmpOffset(float32(x), a)
+(a::AudioNode, x::Real) = AmpOffset(float32(x), a)

sampleat(off::AmpOffset, sf, i) =
    off.amplitude + sampleat(off.input, sf, i)


# Linear ramp
immutable LinRamp <: AudioNode
    start::AudioSample
    finish::AudioSample
    duration::Float32
end

function sampleat(ramp::LinRamp, sf, i)
    l = ramp.duration * sf
    i > l ?
        ramp.finish :
        ramp.start + i * (ramp.finish - ramp.start) / l
end


# Array player
type ArrayPlayer <: AudioNode
    samples::Array{Float32}
    index::Int
end

function pull(a::ArrayPlayer, sf, offset, n, buf=Float32[])
    if a.index >= length(samples)
        return zero(Float32)
    end

    last = min(length(a.samples), a.index+n)
    samples[a.index+1:last]
end

