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

    # Display envelope meter
    SCREEN_WIDTH = 150
    SCALE_FACTOR = 5000
    print("\u1b[1G")
    print("\u1b[K")
    val = abs(round(Int, SCALE_FACTOR * y[1]))
    if val > SCREEN_WIDTH
        val = SCREEN_WIDTH
    end
    solidglyph="█"
    print(string(val, "  |", repeat(solidglyph, val)))

    return y
end


#
# Run
#

n = EnvelopeNode(5, 44100)
AudioIO.play(n)
sleep(30)
stop(n)
