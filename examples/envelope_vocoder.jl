using DSP, AudioIO


#
# Envelope Follower
#

type EnvelopeFollower <: AudioIO.AudioRenderer
    in1::AudioIO.AudioNode
    a::Array{Float32, 1}
    b::Array{Float32, 1}
    x_last::Array{Float32, 1}
    y_last::Array{Float32, 1}

    function EnvelopeFollower(cutOff, fs, in1=AudioInput())

        responsetype = Lowpass(cutOff; fs=fs)
        designmethod = Butterworth(2)
        f = digitalfilter(responsetype, designmethod)
        f = DSP.PolynomialRatio(f)
        a = coefa(f)
        b = coefb(f)
        new(in1, a, b, zeros(a), zeros(b))
    end
    EnvelopeFollower(a::AudioIO.AudioNode) = EnvelopeFollower(4, 44100, a)
end

typealias Envelope AudioIO.AudioNode{EnvelopeFollower}

import AudioIO.render
function render(node::EnvelopeFollower, device_input::AudioIO.AudioBuf, info::AudioIO.DeviceInfo)

    # Low pass filter on absolute value of measurement
    input = render(node.in1, device_input, info)
    y = zeros(input)

    for i in 1:length(y)

        y[i] =  (abs(input[i]) * node.b[1]) +
                (node.x_last[1] *  node.b[2]) +
                (node.x_last[2] *  node.b[3]) +
                (node.y_last[1] * -node.a[2]) +
                (node.y_last[2] * -node.a[3])

        node.x_last[2] = node.x_last[1]
        node.y_last[2] = node.y_last[1]
        node.x_last[1] = abs(input[i])
        node.y_last[1] = y[i]
    end

    return y
end


#
# Envelope Plotter
#

type EnvelopePlotter <: AudioIO.AudioRenderer
    in1::AudioIO.AudioNode
    scale_factor::Int
    screen_width::Int

    EnvelopePlotter(a::AudioIO.AudioNode, f, w) = new(a, f, w)
    EnvelopePlotter(a::AudioIO.AudioNode) = new(a, 500, 150)
    EnvelopePlotter() = new(AudioInput(), 500, 150)
end

typealias Plot AudioIO.AudioNode{EnvelopePlotter}

function render(node::EnvelopePlotter, device_input::AudioIO.AudioBuf, info::AudioIO.DeviceInfo)

    input = render(node.in1, device_input, info)

    # Display envelope meter
    print("\u1b[1G")
    print("\u1b[K")
    val = abs(round(Int, node.scale_factor * input[1]))
    if val > node.screen_width
        val = node.screen_width
    end
    solidglyph="█"
    print(string(val, "  |", repeat(solidglyph, val)))
    return input
end



#
# Single channel vocoder
#

type EnvelopeVocoder <: AudioIO.AudioRenderer
    in1::AudioIO.AudioNode

    EnvelopeVocoder(a::AudioIO.AudioNode) = new(a)
    EnvelopeVocoder() = new(AudioInput())
end

typealias Vocode AudioIO.AudioNode{EnvelopeVocoder}

function render(node::EnvelopeVocoder, device_input::AudioIO.AudioBuf, info::AudioIO.DeviceInfo)

    input = render(node.in1, device_input, info)
    output = input .* (rand(Float32, size(input)) * 2 -1)
end


#
# Run
#

p = play(Vocode(Plot(Envelope(AudioInput()))))
play(p)
sleep(0.00001)
@printf("\n\nFollow Envelope\n")
sleep(100)
stop(p)
