local board = gainerLib.new("/dev/ttyUSB0")

local buttonChanged = function(data)
  print("Button:", data)
end

function setup()
  board:init()
  board:setInterrupt("button", buttonChanged)
end


function loop()
  board:turnOnLED()
  board:wait(1)
  board:turnOffLED()
  board:wait(1)
  board:peekDigitalInput()
  for i = 1, board.digitalInput.lenght do
      print(board.digitalInput[i])
  end
end
