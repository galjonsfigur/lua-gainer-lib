local gainer = require 'gainerv3'

board = gainer.new()

function setup()
  board:init()
end

function loop()
  board:digitalWrite(gainer.HIGH, gainer.LED)
  board:wait(1)
  board:digitalWrite(gainer.LOW, gainer.LED)
  board:wait(1)
end

board:start(setup, loop)