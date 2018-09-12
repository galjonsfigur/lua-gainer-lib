---
-- Simple example for LED diode dimming via potentiometer
-- using analogRead and analogWrite on gainer device.
-- TODO: description
function setup()
  board:init()
  board:beginDigitalSampling()
  for i = 1, 100 do
    print("Sample "..i..":", board:getSample(1,2,3,4))
    board:wait(0.5)
  end
  board:endSampling()
end

function loop()
  board:wait(1)
end