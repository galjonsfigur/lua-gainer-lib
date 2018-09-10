-- Prefix '_' was added to all functions to prevent override them mistake in user program.

local native = require 'nativeFunctions'
local inspect = require('inspect')

local commands = {
  [1] =             {command = "KONFIGURATION_1*", responseRegex = "KONFIGURATION_1%*"},
  [2] =             {command = "KONFIGURATION_2*", responseRegex = "KONFIGURATION_2%*"},
  reset =           {command = "Q*", responseRegex = "Q%*"},
  ledHigh =         {command = "h*", responseRegex = "h%*"},
  ledLow =          {command = "l*", responseRegex = "l%*"},
  getAllDigital =   {command = "R*", responseRegex = "R%x%x%x%x%*$"}, 
  setAllDigital =   {command = "Dnnnn*", responseRegex = "D%x%x%x%x%*"}, 
  setDigitalLow =   {command = "Ln*", responseRegex = "L%d%*"},
  setDigitalHigh =  {command = "Hn*", responseRegex = "H%d%*"},
  getAnalog =       {command =  "Sn*", responseRegex = "S%x%x%*"},    
  getAllAnalog4 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%*$"},
  getAllAnalog8 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%*$"},
  setAnalog =       {command = "anxx*", responseRegex = "a%x%x%x%*"},
  setMatrix =       {command = "anxxxxxxxx*", responseRegex = "a%x%x%x%x%x%x%x%x%*"},
  setAllAnalog4 =   {command = "Axxxxxxxx*", responseRegex = "a%x%x%x%x%x%x%x%x%*"},
  setAllAnalog8 =   {command = "Axxxxxxxxxxxxxxxx", responseRegex = "a%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%*"},
  getAllAnalog4C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%x%*$"}, 
  getAllAnalog8C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%xi%x%x%x%x%x%x%x%x%*$"},
  exitContinous =   {command = "E*", responseRegex = "E%*"}
}
  
-- Analog inputs, Digital inputs, Analog outputs, Digital outputs  
local configurations = {
[0] = {0, 0, 0, 0},
[1] = {4, 4, 4, 4},
[2] = {8, 0, 4, 4},
[3] = {4, 4, 8, 0},
[4] = {8, 0, 8, 0},
[5] = {0,16, 0, 0},
[6] = {0, 0,16, 0},
[7] = {0, 8, 8, 0},
[8] = {0, 8, 0, 8}
}

board = {
  -- Static data 
  serialPort = "/dev/ttyUSB0",
  debug = true, 
  verboseMode = false,
  -- Other
  shrinkBuffer = 0, -- Counting from the end of serial buffer
  -- Gainer parameters
  configuration = 1,
  continousMode = {status = false, command = {}},
  lastDigitalInput = {},
  lastAnalogInput = {},
  lastAnalogOutput = {},
  lastDigitalOutput = 0,
  interrupts = {
    button = {data = "F", isr =  nil}
  }
}
-- Modes or other states

HIGH = true
LOW = false
LED = 0
SINGLE = 1
MULTI = 2

-- Neat functions

local function pack(...)
  return {...}
end

local function isEmpty(table)
  for _,_ in pairs(table) do
    return false
  end
    return true
end

local function _sendCommand(command)
  assert(native.serial.write(command.command), "Command write failed!")
end

function board.sendCommand(self, command)
  assert(native.serial.write(command), "Command write failed!")
end
function board.delay(self, s)
  native.sleep(s)
end
local _serialListener = coroutine.create( function()
  local serialBuffer, regexBuffer, r = "", "", ""
  local interruptData = {}
  local bufPosition = 0
  local interrupts = { name = "button", regex = ".*([N,F])%*", data = "F" }
  while true do
    -- Read input
    r = native.serial.read();
    if #r > 0 then
      serialBuffer = serialBuffer..r
    end   
    --Search for interrupt
    regexBuffer = string.match(serialBuffer, interrupts.regex)
    if regexBuffer and regexBuffer ~= interrupts.data then
      interruptData[interrupts.name] = regexBuffer
      interrupts.data = regexBuffer
    end  
    -- "Send" serial buffer
    --if not next(interruptData) then interruptData = nil end
    coroutine.yield(interruptData, serialBuffer)
    interruptData = {}
    if board.shrinkBuffer ~= 0 then
      serialBuffer = string.sub(serialBuffer, board.shrinkBuffer)
      board.shrinkBuffer = 0;    
    end
  end
end)

local function _interruptHandler(interruptData)
 if not isEmpty(interruptData) then
  if interruptData.button == 'N' then
    board.interrupts.button.data = true
  else
    board.interrupts.button.data = false
  end
    if board.interrupts.button.isr then board.interrupts.button.isr(board.interrupts.button.data)  end
 end
end

local function _waitForResponse(command, timeout)
  if board.debug then print("Command:", command.command) end
  local maxTime = timeout or 1.5 -- Default timeout in seconds
  local interruptData = {}
  local serialBuffer = ""
  local result = ""
  local ntime = os.clock() + maxTime
  local findBegin, findEnd = nil, nil
  repeat 
    interruptData, serialBuffer = select(2, assert(coroutine.resume(_serialListener)))
    if interruptData ~= {} then _interruptHandler(interruptData) end
    
    findBegin, findEnd = string.find(serialBuffer, command.responseRegex)          
    if findBegin then
      result = string.sub(serialBuffer,findBegin,findEnd)
      board.shrinkBuffer = findEnd
     end        
    if result ~= "" and result ~= nil then break end
    -- Check if it was an error message
    if string.match(serialBuffer, "!%*") then
      print("Error: Command failed on device.", command.command, serialBuffer)
      break
    end  
  until os.clock() > ntime
      
  if result ~= ""  and result ~= nil then
    if board.debug then print("OK:", command.command, result) end
    return result
  else
    print("Warning: No response in timeout.", command.command, serialBuffer)
    return nil
  end   
end

-- Board functions
function board.init(self, serialPort, configuration)
  self.serialPort = serialPort or self.serialPort
  self.configuration = configuration or self.configuration
  
  assert(native.serial.open(self.serialPort), "Open failed.");
  if self.debug then print("Opened port socket.") end
  assert(native.serial.setBaud(native.serial.B38400), "Set baud failed.");
  if self.debug then print("Waiting for buffer.") end
    
  _sendCommand(commands.reset)
  _waitForResponse(commands.reset)
  native.sleep(0.05) -- Reset takes time
  
  
  _sendCommand(commands[self.configuration])
  _waitForResponse(commands[self.configuration])
  native.sleep(0.05) -- Configuration takes time
   
  -- self.lastDigitalInput.lenght, self.lastAnalogInput.lenght = unpack(configurations[self.configuration]) --TODO: remove underscores
end

function board.attatchInterrupt(self, isrName, isr)
  self.interrupts[isrName].isr = isr
end

function board.turnOnLED(self)
  _sendCommand(commands.ledHigh)
  _waitForResponse(commands.ledHigh)
end

function board.turnOffLED(self)
  _sendCommand(commands.ledLow)
  _waitForResponse(commands.ledLow)
end

function board.wait(self, time)
  local ntime = os.clock() + time
  repeat
    _interruptHandler((select(2, coroutine.resume(_serialListener))))
  until os.clock() > ntime
end

function board.digitalRead(self, ...)
  local result = ""
  local input = 0
  
  _sendCommand(commands.getAllDigital)
  result = _waitForResponse(commands.getAllDigital)
  assert(result, "Error: Check board or support of command in configuraion")
  
  result = tonumber(string.match(result, "(%d%d%d%d)"))
  for i = 0, configurations[self.configuration][2] do
    input = bit.band(1, bit.rshift(result, i))
    if input == 1 then self.lastDigitalInput[i + 1] = true
    else self.lastDigitalInput[i + 1] = false end
  end
  
  -- If there are additional arguments
  if select("#", ...) > 0 and select("#", ...) <= configurations[self.configuration][2] then
    local output = {}
    for i = 1, select("#", ...) do
      table.insert(output, #output + 1, self.lastDigitalInput[(select(i, ...))])  
    end
    return unpack(output)
  end  
end

function board.digitalWrite(self, mode, ...)
  assert(select("#", ...) ~= 0, "Error: not enough arguments.")
  if select("#", ...) == 1 then        
    if mode then
       if (select(1, ...)) == LED then 
        _sendCommand(commands.ledHigh)
        _waitForResponse(commands.ledHigh)       
       else       
        _sendCommand({
          command = string.gsub(commands.setDigitalHigh.command,"n", (select(1, ...)) - 1),
          responseRegex = commands.setDigitalHigh.responseRegex
        })
        _waitForResponse(commands.setDigitalHigh)
        self.lastDigitalOutput = bit.bor(self.lastDigitalOutput, bit.lshift(1, (select(1, ...)) - 1))
      end
    else
      if (select(1, ...)) == LED then
        _sendCommand(commands.ledLow)
        _waitForResponse(commands.ledLow) 
      else
        _sendCommand({
          command = string.gsub(commands.setDigitalLow.command,"n", (select(1, ...)) - 1),
          responseRegex = commands.setDigitalLow.responseRegex
        })
        _waitForResponse(commands.setDigitalLow)
        self.lastDigitalOutput = bit.bor(self.lastDigitalOutput, bit.lshift(0, (select(1, ...)) - 1))            
      end   
    end
    
  else
    data = self.lastDigitalOutput
    for i = 1, select("#", ...) do    
      if mode then
        if (select(i, ...)) == LED then 
          _sendCommand(commands.ledHigh)
          _waitForResponse(commands.ledHigh) 
        else
          data = bit.bor(data, bit.lshift(1, (select(i, ...)) - 1))
        end 
      else 
        if (select(i, ...)) == LED then     
          _sendCommand(commands.ledLow)
          _waitForResponse(commands.ledLow)
        else
          data = bit.bor(data, bit.lshift(0, (select(i, ...)) - 1))
        end
      end
    end
    _sendCommand({
      command = string.gsub(commands.setAllDigital.command, "nnnn", string.upper(string.format("%04x", data))),
      responseRegex = commands.setDigitalLow.responseRegex
    })
    _waitForResponse(commands.setAllDigital)
    self.lastDigitalOutput = data             
  end
end

function board.setConfiguration(self, configuration)
  if configuration ~= self.configuration then
    self.configuration = configuration
    _sendCommand(commands.reset)
    _waitForResponse(commands.reset)
    native.sleep(0.05) -- Reset takes time
    
    
    _sendCommand(commands[configuration])
    _waitForResponse(commands[configuration])
    native.sleep(0.05) -- Configuration takes time    
  end
end

function board.analogRead(self, ...)
  local result = ""
  if configurations[self.configuration][1] == 4 then
    _sendCommand(commands.getAllAnalog4)
    result = _waitForResponse(commands.getAllAnalog4)
  elseif configurations[self.configuration][1] == 8 then
    _sendCommand(commands.getAllAnalog8)
    result = _waitForResponse(commands.getAllAnalog8)  
  else
    error("Error: command not supported in current configuration")  
  end
  
  assert(result, "Error: check board or support of command in configuration")
  local i = 1
  for value in string.gmatch(result, "(%x%x)") do
    self.lastAnalogInput[i] = tonumber("0x"..value)
    i = i + 1
  end
  
  if select("#", ...) > 0 and select("#", ...) <= configurations[self.configuration][1] then
    local output = {}
    for i = 1, select("#", ...) do
      table.insert(output, #output + 1, self.lastAnalogInput[(select(i, ...))])  
    end
    return unpack(output)
  end  
end

--- ... = port/column number, value OR values for all ports
function board.analogWrite(self, mode, ...)
  if mode == SINGLE then
    assert(select("#", ...) == 2, "Error: not enough arguments.")
    if self.configuration ~= 7 then
      _sendCommand({
        command = (string.gsub(
          string.gsub(commands.setAnalog.command, "n", (select(1, ...)) - 1),
          "xx",
          string.upper(string.format("%02x", (select(2, ...)))))),
        responseRegex = commands.setAnalog.responseRegex
      })
      _waitForResponse(commands.setAnalog)
    else   
      _sendCommand({
        command = (string.gsub(
          string.gsub(commands.setMatrix.command, "n", (select(1, ...)) - 1),
          "xxxxxxxx",
          string.upper(string.format("%08x", (select(2, ...)))))),
        responseRegex = commands.setMatrix.responseRegex
      })
      _waitForResponse(commands.setMatrix)
    end
  else 
    assert(select("#", ...) ~= 0, "Error: not enough arguments.")
    local payload = ""
    local output = pack(...)   
    for i = 1, configurations[self.configuration][3] do
      if (select(i, ...)) then
       payload = payload .. string.format("%02x", (select(i, ...))) 
       output[i] = (select(i, ...))     
      else
       payload = payload .. string.format("%02x", self.lastAnalogOutput[i] or 0) 
      end
    end 
    if configurations[self.configuration][3] == 4 then
      _sendCommand({
        command = (string.gsub(commands.setAllAnalog4.command, "xxxxxxxx", string.upper(payload))),
        responseRegex = commands.setAllAnalog4.responseRegex
      })
      _waitForResponse({
      command = commands.setAllAnalog4.command,
      responseRegex = "A%*"
      })
    elseif configurations[self.configuration][3] == 8 then
      _sendCommand({
        command = (string.gsub(commands.setAllAnalog8.command, "xxxxxxxxxxxxxxxx", string.upper(payload))),
        responseRegex = commands.setAllAnalog8.responseRegex
      })
      _waitForResponse({
      command = commands.setAllAnalog8.command,
      responseRegex = "A%*"
      })           
    end
    self.lastAnalogOutput = output
  end
end

function board.getSample(self, ...)
  local result = ""
  result = _waitForResponse(self.continousMode.command)
  assert(result, "Error: check board or support of command in configuration")
  if self.continousMode.command == commands.getAllAnalog4C 
  or self.continousMode.command == commands.getAllAnalog8C then
    local i = 1
    for value in string.gmatch(result, "(%x%x)") do
      self.lastAnalogInput[i] = tonumber("0x"..value)
      i = i + 1
    end
    if select("#", ...) > 0 and select("#", ...) <= configurations[self.configuration][1] then
      local output = {}
      for i = 1, select("#", ...) do
        table.insert(output, #output + 1, self.lastAnalogInput[(select(i, ...))])  
      end
      return unpack(output)
    end      
    --TODO: add digital sampling
  end
end

function board.endSampling(self)
  if self.continousMode.status then
    _sendCommand(commands.exitContinous)
    self.continousMode.status = false
    self.continousMode.command = {}
  else
    print("Warning: board is not in continous mode.")
  end
end
function board.beginAnalogSampling(self)
  if configurations[self.configuration][1] == 4 then
    _sendCommand(commands.getAllAnalog4C)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllAnalog4C
  elseif configurations[self.configuration][1] == 8 then
    _sendCommand(commands.getAllAnalog8C)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllAnalog8C  
  else
    print("Error: analog sampling is not supported in current configuration.")
  end
end

-- Main program
if #arg ~= 0 then
  dofile(arg[1])
else
 error([[No script file specified.
 Use: ./gainer path/to/script.lua
 ]])
end

setup()
while true do
  loop()
  if board.continousMode.status then
    board.getSample(board)
  end 
  --TODO: Interrupt handling
end


