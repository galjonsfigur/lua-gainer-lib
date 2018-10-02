local gainer = require 'gainer'

---
-- Simple example for using 8x8 LED Matrix with GAINER device.
local board = gainer.new()

local checkerboardA = {
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0
}

local checkerboardB = {
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F,
0xF0F0F0F0,
0x0F0F0F0F
}

local function setup()
  board:init(_, 7)
end

--TODO: chean code
local function loop()
  --for i, value in ipairs(checkerboardA) do
  --  board:analogWrite(gainer.SINGLE, i, value)
  --end
  board:setMatrix(checkerboardA)
  board:wait(1)
  --for i, value in ipairs(checkerboardB) do
   -- board:analogWrite(gainer.SINGLE, i, value)
  --end
  board:setMatrix(checkerboardB)
  board:wait(1)
end

board:start(setup, loop)