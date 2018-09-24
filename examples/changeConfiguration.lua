---
-- Simple example for changing configurations on gainer device.
function setup()
  board:init()
end

function loop()
  -- It takes some time to change between
  -- and current output is set to default state.
  board:setConfiguration(1)
  board:digitalWrite(HIGH, LED)
  board:wait(1)
  board:setConfiguration(2)
  board:digitalWrite(LOW, LED)
  board:wait(1)
end