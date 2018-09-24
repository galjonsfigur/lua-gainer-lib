---
-- Simple example for writing digital output on gainer device.
function setup()
  board:init()
end

function loop()
  -- On gainer device, writing to only 1 output like this:
  board:digitalWrite(HIGH, 1)
  -- uses different command than writing to multiple outputs like this:
  board:digitalWrite(HIGH, 1, 2, 3, 4)
  -- but both methods can be used.
  -- It is possible to set os-board led like this:
  board:digitalWrite(HIGH, LED)
  -- or like this:
  board:digitalWrite(HIGH, 1, 2, LED, 3) 
  
  board:wait(1)
  board:digitalWrite(LOW, 1, 2, 3, 4, LED) -- setting digital low
  board:wait(1)
end