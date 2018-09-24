---
-- Simple example for writing analog output on gainer device.
function setup()
  board:init()
end

function loop()
  -- On gainer device, writing to only 1 output like this:
  board:analogWrite(SINGLE, 1, 123)
  -- uses different command than writing to multiple outputs like this:
  board:analogWrite(MULTI, 56, 44, 255, 5)
  -- but both methods can be used.
  -- It is possible to only preserve inputs like this:
  board:analogWrite(MULTI, 56, _, _, 5)
  
  board:wait(1)
  board:analogWrite(MULTI, 0, 0, 0, 0) -- setting analog 0 - no voltage
  board:wait(1)
end