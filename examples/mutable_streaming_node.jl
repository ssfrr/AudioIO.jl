# This demos how real-time audio manipulation can be done using AudioNodes. To
# run it, hook up some input audio to your default recording device and run the
# script. The demo will run for 10 seconds alternating the node between a muted
# and unmuted state
using AudioIO

type MutableRenderer <: AudioIO.AudioRenderer
  active::Bool
  deactivate_cond::Condition
  muted::Bool

  function MutableRenderer(muted::Bool)
    new(false, Condition(), muted)
  end
end
typealias MutableNode AudioIO.AudioNode{MutableRenderer}

function MutableRenderer()
  MutableRenderer(false)
end

import AudioIO.render
function render(node::MutableRenderer, device_input::AudioIO.AudioBuf, info::AudioIO.DeviceInfo)
  return device_input .* !node.muted
end

function mute(node::MutableNode)
  node.renderer.muted = true
end

function unmute(node::MutableNode)
  node.renderer.muted = false
end

mutableNode = MutableNode(false)
AudioIO.play(mutableNode)
muteTransitions = { true => unmute, false => mute }
for i in 1:10
  sleep(1)
  muteTransitions[mutableNode.renderer.muted](mutableNode)
end
