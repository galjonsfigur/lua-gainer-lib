---
-- Simple example for LED diode dimming via potentiometer
-- using analogRead and analogWrite on gainer device.
-- Commection diagram:
-- LED pin to aout 0
-- Edge Pins of potentiometer to 5V and GND
-- Middle pin of potentiometer to ain 0

local result = 0
function setup()
  board:init()
  board.debug = false
end

function loop()
  result = board:analogRead(1)
  board:analogWrite(SINGLE, 1, result)
end