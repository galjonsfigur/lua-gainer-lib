-- Prefix '_' was added to all functions to prevent override them mistake in user program.

local native = require 'nativeFunctions'
local conf = require 'conf'

gainerLib = {}


local function _pack(...)
   return {...}
end


---
-- Coroutine that reads serial input, searching for interrupting signals (like button)
-- and buffers serial input.
local _serialListener = coroutine.create( function(defaultInterruptTable)
  local serialBuffer = ""
  local interruptData = {}
  local regexBuffer = ""
  local bufPosition = 0
  local interruptTable = defaultInterruptTable
  while true do
    -- Read input
    local r = native.serial.read();
    if #r > 0 then
      serialBuffer = serialBuffer..r
    end
   
     --Search for interrupts
    for i, key in pairs(interruptTable) do
      --if not (string.sub(serialBuffer, bufPosition)) then print("E:", serialBuffer, bufPosition) end
      _, bufPos, regexBuffer = string.find(string.sub(serialBuffer, bufPosition), key.regex)
      if bufPos then bufPosition = bufPos end 
      if regexBuffer and regexBuffer ~= key.data then
        table.insert(interruptData,{name = key.name, data = regexBuffer})
        key.data = regexBuffer
      end
    end   
    -- "Send" serial buffer
    coroutine.yield(interruptData, serialBuffer)
    interruptData = {}
    --TODO: shrink serial buffer sometimes
  end
end)

local function _sendCommand(command)
  assert(native.serial.write(command), #command)
end

local function _interruptHandler(interruptData, isrTable)
  if interruptData then
    for i, key in pairs(interruptData) do
      isrTable[key.name].data = key.data   
      if isrTable[key.name].isr then isrTable[key.name].isr(key.data)  end
    end
  end
end

local function _wait(self, time)
  local ntime = os.clock() + time
  repeat
    _interruptHandler(select(2, coroutine.resume(_serialListener)), self.interrupts)
  until os.clock() > ntime
end

local function _waitForResponse(command, bufferPosition, isrTable, timeout)
  print("command:", command.command)
  local maxTime = timeout or 1.5 -- Default timeout in seconds
  local bufPos = bufferPosition or 0
  local interruptData = {}
  local serialBuffer = ""
  local result = ""
  local ntime = os.clock() + maxTime
  local findBegin, findEnd = nil, nil
  repeat 
    _, interruptData, serialBuffer = coroutine.resume(_serialListener)
    if interruptData then _interruptHandler(interruptData, isrTable) end
    
    serialBuffer = string.sub(serialBuffer, bufPos) --Cut it
    findBegin, findEnd = string.find(serialBuffer, command.responseRegex)          
    if findBegin then
      result = string.sub(serialBuffer,findBegin,findEnd)
      bufPos = findEnd
     end        
    if result ~= "" and result ~= nil then break end
    -- Check if it was an error message
    if string.match(serialBuffer, command.errorRegex) then
      print("Error: Command failed on device.", command.command, serialBuffer)
      break
    end  
  until os.clock() > ntime
      
  if result ~= ""  and result ~= nil then
    print("OK:", command.command, result)
    return result, bufPos
  else
    print("Warning: No response in timeout.", command.command, serialBuffer)
    return nil
  end   
end

local function _init(self)
  assert(native.serial.open(self.serialPort), "Open failed.");
  if debug then print("Opened port socket.") end
  assert(native.serial.setBaud(native.serial.B38400), "Set baud failed.");
  if debug then print("Waiting for buffer.") end
  -- Init coroutine
  coroutine.resume(_serialListener, conf[self.commandSet].interrupts)
  _sendCommand(conf[self.commandSet].commands.reset.command)
  native.sleep(0.05) -- Reset takes time
  _, self.bufferPosition = _waitForResponse(conf[self.commandSet].commands.reset, self.bufferPosition, self.interrupts) 
  _sendCommand(conf[self.commandSet].commands[1].command)
  _, self.bufferPosition = _waitForResponse(conf[self.commandSet].commands[1], self.bufferPosition, self.interrupts)
  native.sleep(0.05) -- Configuration takes time 
  self.digitalInput.lenght = 4
  self.analogInput.lenght = 4
end

local function _setInterrupt(self, isrName, isr)
  self.interrupts[isrName].isr = isr
end

-- Board functions:

local function _turnOnLED(self)
  _sendCommand(conf[self.commandSet].commands.ledHigh.command)
 _, self.bufferPosition = _waitForResponse(conf[self.commandSet].commands.ledHigh, self.bufferPosition, self.interrupts)
end

local function _turnOffLED(self)
  _sendCommand(conf[self.commandSet].commands.ledLow.command)
  _, self.bufferPosition = _waitForResponse(conf[self.commandSet].commands.ledLow, self.bufferPosition, self.interrupts)
end

local function _peekDigitalInput(self)
  local result = ""
  local input = 0
  _sendCommand(conf[self.commandSet].commands.getAllDigital.command)
  result, self.bufferPosition = _waitForResponse(conf[self.commandSet].commands.getAllDigital, self.bufferPosition, self.interrupts)
  
  result = tonumber(string.match(result, conf[self.commandSet].commands.getAllDigital.dataRetrieveRegex))
  for i = 0, self.digitalInput.lenght do
    input = bit.band(1, bit.rshift(result, i))
    if input == 1 then self.digitalInput[i + 1] = true
    else self.digitalInput[i + 1] = false end
  end  
end
-- TODO: Automate serial port setting
function gainerLib.new(serialPort)
  return {
    -- Static data 
    commandSet = "gainer",
    serialPort = serialPort or '/dev/ttyUSB0', 
    debug = true,
    -- Functions
    init = _init,
    turnOnLED = _turnOnLED,
    turnOffLED = _turnOffLED,
    setInterrupt = _setInterrupt,
    peekDigitalInput = _peekDigitalInput,
    delay = native.sleep,  -- TODO: Make dalay with check for interrupts 
    wait = _wait,
    -- Other
    bufferPosition = 0, -- Counting from the end of serial buffer
    -- Gainer parameters
    configuration = 1,
    digitalInput = {lenght = 1},
    analogInput = {lenght = 1},
    interrupts = {
      button = {data = "F", isr =  nil}
    },
    continuousMode = false,
    analogValues = {} --TODO: Make it as LIFO stack or add nice functions
  }
  
    
end

dofile("../tests/example.lua")
setup()
while true do
  loop()
end


