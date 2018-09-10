---
-- Simple example for analog sampling in continous mode on gainer device.
function setup()
  board:init()
  board:beginAnalogSampling()
  for i = 1, 100 do
    print("Sample "..i..":", board:getSample(1,2,3,4))
    board:wait(0.5)
  end
  board:endSampling()
end

function loop()
  board:wait(1)
end