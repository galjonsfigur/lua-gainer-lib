---
-- Example for using button interrupt to control on-board LED on gainer device.

local prevButtonState = false

local buttonChanged = function(data)
  print("Button:", data)
  if data ~= prevButtonState then
    if data == true then
    board:digitalWrite(HIGH, LED)  
    else
    board:digitalWrite(LOW, LED)
    end  
  end
  prevButtonState = data
end

function setup()
  board:init()
  board:attatchInterrupt("button", buttonChanged)
end

function loop()
 --Empty loop
end