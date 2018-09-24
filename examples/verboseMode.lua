---
-- Simple example for blinking on-board LED on gainer device 
-- with verbose mode disabled

function setup()
  board.verboseMode = false
  board:init()
end

function loop()
  board:digitalWrite(HIGH, LED)
  board:wait(1)
  board:digitalWrite(LOW, LED)
  board:wait(1)
end