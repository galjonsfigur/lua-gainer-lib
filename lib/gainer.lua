local native = require 'nativeFunctions'

local commands = {
  [0] =             {command = "KONFIGURATION_0*", responseRegex = "KONFIGURATION_0%*"},
  [1] =             {command = "KONFIGURATION_1*", responseRegex = "KONFIGURATION_1%*"},
  [2] =             {command = "KONFIGURATION_2*", responseRegex = "KONFIGURATION_2%*"},
  [3] =             {command = "KONFIGURATION_3*", responseRegex = "KONFIGURATION_3%*"},
  [4] =             {command = "KONFIGURATION_4*", responseRegex = "KONFIGURATION_4%*"},
  [5] =             {command = "KONFIGURATION_5*", responseRegex = "KONFIGURATION_5%*"},
  [6] =             {command = "KONFIGURATION_6*", responseRegex = "KONFIGURATION_6%*"},
  [7] =             {command = "KONFIGURATION_7*", responseRegex = "KONFIGURATION_7%*"},
  [8] =             {command = "KONFIGURATION_8*", responseRegex = "KONFIGURATION_8%*"},
  reset =           {command = "Q*", responseRegex = "Q%*"},
  ledHigh =         {command = "h*", responseRegex = "h%*", verboseOnly = true},
  ledLow =          {command = "l*", responseRegex = "l%*", verboseOnly = true},
  getAllDigital =   {command = "R*", responseRegex = "R%x%x%x%x%*$"},
  setAllDigital =   {command = "Dnnnn*", responseRegex = "D%x%x%x%x%*", verboseOnly = true},
  getAllDigitalC =  {command = "r*", responseRegex = "r%x%x%x%x%*$"},
  setDigitalLow =   {command = "Ln*", responseRegex = "L%d%*", verboseOnly = true},
  setDigitalHigh =  {command = "Hn*", responseRegex = "H%d%*", verboseOnly = true},
  getAnalog =       {command = "Sn*", responseRegex = "S%x%x%*"},
  getAllAnalog4 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%*$"},
  getAllAnalog8 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%*$"},
  setAnalog =       {command = "anxx*", responseRegex = "a%x%x%x%*", verboseOnly = true},
  setMatrix =       {command = "anxxxxxxxx*", responseRegex = "a%*$", verboseOnly = true},
  setAllMatrix =    {command = "anxxxxxxxx*", responseRegex = "a%*a%*a%*a%*a%*a%*a%*a%*", verboseOnly = true},
  setAllAnalog4 =   {command = "Axxxxxxxx*", responseRegex = "A%*", verboseOnly = true},
  setAllAnalog8 =   {command = "Axxxxxxxxxxxxxxxx", responseRegex = "A%*", verboseOnly = true},
  getAllAnalog4C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%x%*$"},
  getAllAnalog8C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%xi%x%x%x%x%x%x%x%x%*$"},
  exitContinous =   {command = "E*", responseRegex = "E%*"},
  setSensitivity =  {command = "Tx*", responseRegex = "T%x%*"},
  setSamplingMode = {command = "Mn*", responseRegex = "M%d%*"},
  setGain =         {command = "Gxn*", responseRegex = "G%x%d%*"},
  setVerbose =      {command = "Vn*", responseRegex = "V%d%*"},
  getVersion =      {command = "?*", responseRegex =  "?(%d%.%d%.%d%.%d%d)%*"}
}

local M = {
  HIGH = true,
  LOW = false,
  LED = 0,
  SINGLE = 1,
  MULTI = 2,
  VSS = 0,
  AGND = 1
}
-- Analog inputs, Digital inputs, Analog outputs, Digital outputs
local configurations = {
[0] = {0, 0, 0, 0},
[1] = {4, 4, 4, 4},
[2] = {8, 0, 4, 4},
[3] = {4, 4, 8, 0},
[4] = {8, 0, 8, 0},
[5] = {0,16, 0, 0},
[6] = {0, 0, 0,16},
[7] = {0, 8, 8, 0},
[8] = {0, 8, 0, 8}
}

local board = {
  -- Static data
  serialPort = "/dev/ttyUSB0",
  debug = true,
  verboseMode = true,
  -- Other
  serialInterface = {shrinkBuffer = 0}, -- Counting from the end of serial buffer
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

-- Neat functions
--TODO: Better implementation
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

function M.sleep(s)
  native.sleep(s)
end
-- Serial interface is table
local _serialListener = coroutine.create( function(serialInterface)
  local serialBuffer = " "
  local regexBuffer, r
  local interruptData = {}

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
    if serialInterface.shrinkBuffer ~= 0 then
      serialBuffer = string.sub(serialBuffer, serialInterface.shrinkBuffer)
      serialInterface.shrinkBuffer = 0;
    end
  end
end)

local function _interruptHandler(self, interruptData)
 if not isEmpty(interruptData) then
  if interruptData.button == 'N' then
    self.interrupts.button.data = true
  else
    self.interrupts.button.data = false
  end
    if self.interrupts.button.isr then self.interrupts.button.isr(self.interrupts.button.data)  end
 end
end

local function _checkInterrupt(self)
  local interruptData

  interruptData = (select(2, assert(coroutine.resume(_serialListener, self.serialInterface))))
  if interruptData ~= {} then _interruptHandler(self, interruptData) end
end

local function _waitForResponse(command, self, timeout)
  if self.debug then print("Command:", command.command) end
  if not self.verboseMode and command.verboseOnly then return end
  local maxTime = timeout or 1.5 -- Default timeout in seconds
  local interruptData, serialBuffer, result


  local ntime = os.clock() + maxTime
  local findBegin, findEnd
  repeat
    interruptData, serialBuffer = select(2, assert(coroutine.resume(_serialListener, self.serialInterface)))
    if interruptData ~= {} then _interruptHandler(self, interruptData) end

    findBegin, findEnd = string.find(serialBuffer, command.responseRegex)
    if findBegin then
      result = string.sub(serialBuffer,findBegin,findEnd)
      self.serialInterface.shrinkBuffer = findEnd
     end
    if result ~= "" and result ~= nil then break end
    -- Check if it was an error message
    if string.match(serialBuffer, "!%*") then
      print("Error: Command failed on device.", command.command, serialBuffer)
      break
    end
  until os.clock() > ntime

  if result ~= ""  and result ~= nil then
    if self.debug then print("OK:", command.command, result) end
    return result
  else
    print("Warning: No response in timeout.", command.command, serialBuffer)
    return nil
  end
end

-- Board functions
function board:init(serialPort, configuration)
  self.serialPort = serialPort or self.serialPort
  self.configuration = configuration or self.configuration

  assert(native.serial.open(self.serialPort), "Open failed.");
  if self.debug then print("Opened port socket.") end
  assert(native.serial.setBaud(native.serial.B38400), "Set baud failed.");
  if self.debug then print("Waiting for buffer.") end

  _sendCommand(commands.reset)
  _waitForResponse(commands.reset, self)
  native.sleep(0.05) -- Reset takes time

  if self.verboseMode then
  _sendCommand({
     command = string.gsub(commands.setVerbose.command,"n", "1"),
     responseRegex = commands.setVerbose.responseRegex
   })
  else
  _sendCommand({
     command = string.gsub(commands.setVerbose.command,"n", "0"),
     responseRegex = commands.setVerbose.responseRegex
   })
  end
  _waitForResponse(commands.setVerbose, self)
  native.sleep(0.05) -- Setting takes time

  _sendCommand(commands[self.configuration])
  _waitForResponse(commands[self.configuration], self)
  native.sleep(0.05) -- Configuration takes time


end

function board:attatchInterrupt(isrName, isr)
  self.interrupts[isrName].isr = isr
end

function board:wait(time)
  local ntime = os.clock() + time
  repeat
    _interruptHandler(self, (select(2, coroutine.resume(_serialListener, self.serialInterface))))
  until os.clock() > ntime
end

function board:digitalRead(...)
  local result, input

  _sendCommand(commands.getAllDigital)
  result = _waitForResponse(commands.getAllDigital, self)
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

function board:digitalWrite(mode, ...)
  assert(select("#", ...) ~= 0, "Error: not enough arguments.")
  if select("#", ...) == 1 then
    if mode == M.HIGH then
      if (select(1, ...)) == M.LED then
        _sendCommand(commands.ledHigh)
        _waitForResponse(commands.ledHigh, self)
      else
        _sendCommand({
          command = string.gsub(commands.setDigitalHigh.command,"n", (select(1, ...)) - 1),
          responseRegex = commands.setDigitalHigh.responseRegex
        })
        _waitForResponse(commands.setDigitalHigh, self)
        self.lastDigitalOutput = bit.bor(self.lastDigitalOutput, bit.lshift(1, (select(1, ...)) - 1))
      end
    else
      if (select(1, ...)) == M.LED then
        _sendCommand(commands.ledLow)
        _waitForResponse(commands.ledLow, self)
      else
        _sendCommand({
          command = string.gsub(commands.setDigitalLow.command,"n", (select(1, ...)) - 1),
          responseRegex = commands.setDigitalLow.responseRegex
        })
        _waitForResponse(commands.setDigitalLow, self)
        self.lastDigitalOutput = bit.band(self.lastDigitalOutput, bit.bnot(bit.lshift(1, (select(1, ...)) - 1)))
      end
    end

  else
    local data = self.lastDigitalOutput
    --TODO: better iterator
    for i = 1, select("#", ...) do
      if mode == M.HIGH then
        if (select(i, ...)) == M.LED then
          _sendCommand(commands.ledHigh)
          _waitForResponse(commands.ledHigh, self)
        else
          data = bit.bor(data, bit.lshift(1, (select(i, ...)) - 1))
        end
      else
        if (select(i, ...)) == M.LED then
          _sendCommand(commands.ledLow)
          _waitForResponse(commands.ledLow, self)
        else
          data = bit.band(data, bit.bnot(bit.lshift(1, (select(i, ...)) - 1)))
        end
      end
    end
    _sendCommand({
      command = string.gsub(commands.setAllDigital.command, "nnnn", string.upper(string.format("%04x", data))),
      responseRegex = commands.setDigitalLow.responseRegex
    })
    _waitForResponse(commands.setAllDigital, self)
    self.lastDigitalOutput = data
  end
end

function board:setConfiguration(configuration)
  if configuration ~= self.configuration then
    self.configuration = configuration
    _sendCommand(commands.reset)
    _waitForResponse(commands.reset, self)
    native.sleep(0.05) -- Reset takes time
    _sendCommand(commands[configuration])
    _waitForResponse(commands[configuration], self)
    native.sleep(0.05) -- Configuration takes time
  end
end

function board:analogRead(...)
  local result = ""
  -- Single pin read
  if select("#", ...) == 1 then
   _sendCommand({
     command = string.gsub(commands.getAnalog.command,"n", (select(1, ...)) - 1),
     responseRegex = commands.getAnalog.responseRegex
   })
   result = _waitForResponse(commands.getAnalog, self)
   assert(result, "Error: Check board or support of command in configuraion")
   result = tonumber("0x"..string.match(result, "S(%x%x)%*"))
   self.lastAnalogInput[(select(1, ...))] = result
   return result
  -- For more pins
  else
    if configurations[self.configuration][1] == 4 then
      _sendCommand(commands.getAllAnalog4)
      result = _waitForResponse(commands.getAllAnalog4, self)
    elseif configurations[self.configuration][1] == 8 then
      _sendCommand(commands.getAllAnalog8)
      result = _waitForResponse(commands.getAllAnalog8, self)
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
      for j = 1, select("#", ...) do
        table.insert(output, #output + 1, self.lastAnalogInput[(select(j, ...))])
      end
      return unpack(output)
    end
  end
end

--TODO: Check if in conf 7
function board:setMatrix(table)
  local payload = ""
  for i, value in ipairs(table) do
  payload = payload .. (string.gsub(
    string.gsub(commands.setMatrix.command, "n", i - 1),
    "xxxxxxxx",
    string.upper(string.format("%08x", value))))
  end
  _sendCommand({
    command = payload,
    responseRegex = commands.setMatrix.responseRegex
  })
  _waitForResponse(commands.setAllMatrix, self)
end

--- ... = port/column number, value OR values for all ports
-- Can be used to control 8x8 LED Matrix
function board:analogWrite(mode, ...)
  if mode == M.SINGLE then
    assert(select("#", ...) == 2, "Error: not enough arguments.")
    if self.configuration ~= 7 then
      _sendCommand({
        command = (string.gsub(
          string.gsub(commands.setAnalog.command, "n", (select(1, ...)) - 1),
          "xx",
          string.upper(string.format("%02x", (select(2, ...)))))),
        responseRegex = commands.setAnalog.responseRegex
      })
      _waitForResponse(commands.setAnalog, self)
    else
      _sendCommand({
        command = (string.gsub(
          string.gsub(commands.setMatrix.command, "n", (select(1, ...)) - 1),
          "xxxxxxxx",
          string.upper(string.format("%08x", (select(2, ...)))))),
        responseRegex = commands.setMatrix.responseRegex
      })
      _waitForResponse(commands.setMatrix, self)
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
      --TODO:Check
      _waitForResponse({
      command = commands.setAllAnalog4.command,
      responseRegex = commands.setAllAnalog4.responseRegex
      }, self)
    elseif configurations[self.configuration][3] == 8 then
      _sendCommand({
        command = (string.gsub(commands.setAllAnalog8.command, "xxxxxxxxxxxxxxxx", string.upper(payload))),
        responseRegex = commands.setAllAnalog8.responseRegex
      })
      _waitForResponse({
      command = commands.setAllAnalog8.command,
      responseRegex = commands.setAllAnalog8.responseRegex
      }, self)
    end
    self.lastAnalogOutput = output
  end
end
--TODO check if working digital
function board:getSample(...)
  if not self.continousMode.status then
    print("Warning: board in not in continous mode")
    return
  end
 
  local result = _waitForResponse(self.continousMode.command, self)
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
      for j = 1, select("#", ...) do
        table.insert(output, #output + 1, self.lastAnalogInput[(select(j, ...))])
      end
      return unpack(output)
    end
  elseif self.continousMode.command == commands.getAllDigitalC then
    result = tonumber(string.match(result, "(%d%d%d%d)"))
    for i = 0, configurations[self.configuration][2] do
      if bit.band(1, bit.rshift(result, i)) == 1 then self.lastDigitalInput[i + 1] = true
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
end

function board:endSampling()
  if self.continousMode.status then
    _sendCommand(commands.exitContinous)
    --TODO: Wait for response
    self.continousMode.status = false
    self.continousMode.command = {}
  else
    print("Warning: board is not in continous mode.")
  end
end

function board:beginAnalogSampling()
--TODO: Wait for response
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

function board:beginDigitalSampling()
--TOSDO: Wait for response
  if configurations[self.configuration][1] ~= 0 then
    _sendCommand(commands.getAllDigitalC)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllDigitalC
  else
    print("Error: analog sampling is not supported in current configuration.")
  end
end

--TODO: Add example
function board:setSensitivity(value)
  if self.configuration ~= 8 then
    print("Error: Capacitive sensing is not supported in current configuration.")
  else
   _sendCommand({
     command = string.gsub(commands.setSensitivity.command,"x", string.upper(string.format("%x", value))),
     responseRegex = commands.setSensitivity.responseRegex
   })
   _waitForResponse(commands.setSensitivity, self)
  end
end

--TODO: Add example
function board:setSamplingMode(mode)
  if mode then
   _sendCommand({
     command = string.gsub(commands.setSamplingMode.command,"n", "1"),
     responseRegex = commands.setSamplingMode.responseRegex
   })
  else
   _sendCommand({
     command = string.gsub(commands.setSamplingMode.command,"n", "0"),
     responseRegex = commands.setSamplingMode.responseRegex
   })
  end
  _waitForResponse(commands.setSamplingMode, self)
end

--TODO: Add example
function board:setGain(reference, value)
  _sendCommand({
    command = string.gsub(
      string.gsub(commands.setGain.command, "x", string.upper(string.format("%x", value))),
      "n", reference),
    responseRegex = commands.setGain.responseRegex
  })
  _waitForResponse(commands.setGain, self)
end

--TODO: Add example
function board:getVerion()
  _sendCommand(commands.getVersion)
  local result = _waitForResponse(commands.getVersion, self)
  assert(result, "Error: check board or support of command in configuration")
  return string.match(result, commands.getVersion.responseRegex)
end


function board:start(setup, loop)
  setup = setup or function() end
  loop = loop or function() return end

  setup()
  while true do
  loop()
  if self.continousMode.status then
    self:getSample()
  end
  _checkInterrupt(self)
  end
end

function M.new()
  return board
end
return M
