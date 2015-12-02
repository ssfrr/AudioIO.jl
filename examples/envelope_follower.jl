using DSP, AudioIO


#
# Envelope Follower
#

type EnvelopeFollower <: AudioIO.AudioRenderer
    a::Array
    b::Array
    x_last::Array
    y_last::Array

    function EnvelopeFollower(cutOff, fs)

        responsetype = Lowpass(cutOff; fs=fs)
        designmethod = Butterworth(2)
        f = digitalfilter(responsetype, designmethod)
        f = DSP.PolynomialRatio(f)
        a = coefa(f)
        b = coefb(f)
        new(a, b, zeros(a), zeros(b))
    end
end

typealias EnvelopeNode AudioIO.AudioNode{EnvelopeFollower}

import AudioIO.render
function render(node::EnvelopeFollower, device_input::AudioIO.AudioBuf, info::AudioIO.DeviceInfo)

    # Low pass filter on absolute value of measurement
    y = zeros(device_input)

    for i in 1:length(y)

        y[i] =  (abs(device_input[i]) * node.b[1]) +
                (node.x_last[1] *  node.b[2]) +
                (node.x_last[2] *  node.b[3]) +
                (node.y_last[1] * -node.a[2]) +
                (node.y_last[2] * -node.a[3])

        node.x_last[2] = node.x_last[1]
        node.y_last[2] = node.y_last[1]
        node.x_last[1] = abs(device_input[i])
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

typealias PlotterNode AudioIO.AudioNode{EnvelopePlotter}

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
# Run
#


p = PlotterNode(EnvelopeNode(5, 44100))
play(p)
sleep(0.00001)
@printf("\n\nFollow Envelope\n")
sleep(10)
stop(p)

@printf("\n\nFollow Absolute Signal\n")
p = PlotterNode()
play(p)
sleep(10)
stop(p)


