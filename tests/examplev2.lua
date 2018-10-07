local gainer = require 'gainer'
--local simplex = require '2d'
---
-- Simple example for using 8x8 LED Matrix with GAINER device.
local board = gainer.new()

local buffer = {}
local line = ""

local function setup()
  board.debug = false
  board:init(_, 7)
end

--TODO: chean code
local function loop()
local loopI = 1
  for i = 1, 8 do
    for j = 1, 8 do
      --local noise = math.ceil((simplex(math.random(1*i, 15*i),math.random(1*j, 15*j)) + 1) * 7)
      local noise = math.random(0,15)
      line = line .. string.format("%x", noise)
      --print(noise)
    end
    --board:analogWrite(gainer.SINGLE, i, tonumber("0x" .. line))
    buffer[i] = tonumber("0x" .. line)
    --print(line)
    line = ""
  end
  --for i, value in ipairs(checkerboardA) do
  --  board:analogWrite(gainer.SINGLE, i, value)
  --end
  board:setMatrix(buffer)
  board:wait(0.03)
  --for i, value in ipairs(checkerboardB) do
   -- board:analogWrite(gainer.SINGLE, i, value)
  --end
  loopI = loopI + math.random(100,10000)
  end

board:start(setup, loop)