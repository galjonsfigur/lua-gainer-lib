---
-- Simple example for blinking on-board LED on gainer device.
function setup()
  ---
  -- Default port is /dev/ttyUSB0 and default configuration is 1
  -- if your serial port adress is different (for example /dev/ttyUSB1
  -- you can use:
  --   board:init("/dev/ttyUSB0")
  -- or even set other configuration as default:
  --   board:init("/dev/ttyUSB0", 2)
  
  board:init()
end

function loop()
  board:digitalWrite(HIGH, LED)
  board:wait(1)
  board:digitalWrite(LOW, LED)
  board:wait(1)
end