local buttonChanged = function(data)
  print("Button:", data)
end

function setup()
  board:init()
  board:attatchInterrupt("button", buttonChanged)
  board.debug = true
end


function loop()
  board:digitalWrite(HIGH, LED)
  --board:digitalWrite(HIGH, 1, 3, 2, 4) 
  --board:analogWrite(SINGLE, 1, 100) 
  board:analogWrite(MULTI, 200, 0, 0, 0)
  board:wait(1)
  board:digitalWrite(LOW, LED)
  --board:digitalWrite(LOW, 1, 3, 2, 4)
  --board:analogWrite(SINGLE, 1, 0)
    board:analogWrite(MULTI, _, _, _, 200)
  
  board:wait(1)
  
  --board:digitalRead()
  --print(board:digitalRead(1,2))
  
  --print(board:analogRead(4))
--[[  
  --dimming

  for i = 0, 254 do
    board:sendCommand("a0"..string.upper(string.format("%02x", i)).."*")
    --board:analogWrite(SINGLE, 1, i)
    board:sendCommand("a3"..string.upper(string.format("%02x", 255 - i)).."*")
   -- board:analogWrite(SINGLE, 4, 255 - i)   
     board:delay(0.01)
   
  end
  for i = 254, 0, -1 do
      --board:analogWrite(SINGLE, 1, i)
      --board:analogWrite(SINGLE, 4, 255 - i)     
    board:sendCommand("a0"..string.upper(string.format("%02x", i)).."*")
    board:sendCommand("a3"..string.upper(string.format("%02x", 255 - i)).."*")
        board:delay(0.01)
    
  end 
 ]]-- 
  --board:setConfiguration(2)
 -- board:peekDigitalInput()
  --for i = 1, board.lastDigitalInput.lenght do
   --   print(board.lastDigitalInput[i])
 -- end
end
