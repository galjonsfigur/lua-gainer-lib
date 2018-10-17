---
-- LuaJIT library to control GAINER - an USB I/O board
-- for educational purpose. It uses serial port connection and simple commands
-- allowing for easily use digital input, digital output, analog input
-- and analog output from environment.
-- @script gainer
-- @author galion
-- @license MIT

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
  setAllAnalog8 =   {command = "Axxxxxxxxxxxxxxxx*", responseRegex = "A%*", verboseOnly = true},
  getAllAnalog4C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%x%*$"},
  getAllAnalog8C =  {command = "i*", responseRegex = "i%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%*$"},
  exitContinous =   {command = "E*", responseRegex = "E%*"},
  setSensitivity =  {command = "Tx*", responseRegex = "T%x%*"},
  setSamplingMode = {command = "Mn*", responseRegex = "M%d%*"},
  setGain =         {command = "Gxn*", responseRegex = "G%x%d%*"},
  setVerbose =      {command = "Vn*", responseRegex = "V%d%*"},
  getVersion =      {command = "?*", responseRegex =  "?(%d%.%d%.%d.*)%*"}
}

local M = {
  HIGH = true,
  LOW = false,
  LED = 0,
  SINGLE = 1,
  MULTI = 2,
  VSS = false,
  AGND = true,
  ALL_PORTS = false,
  AIN_ONLY = true
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
[8] = {0, 4, 0, 8}
}

local board = {
  -- Static data
  serialPort = "/dev/ttyUSB0",
  debug = false,
  verboseMode = false,
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
local function pack(...)
  return {...}
end

--TODO: Better implementation
local function isEmpty(table)
  for _,_ in pairs(table) do
    return false
  end
    return true
end

local function _sendCommand(command)
  assert(native.serial.write(command.command), "Command write failed!")
end

---
-- Halts execution of script for s seconds.
-- Interrupts will not be caught when using this function.
-- @param s seconds for delay - decimals can be used.
function M.sleep(s)
  native.sleep(s)
end
-- Serial interface is table to be able to pass it to coroutine as reference, not as a value.
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

---
-- Inits gainer library.
-- @param serialPort Serial port that is connected to GAIER board like "/dev/ttyS0".
-- Default port is "/dev/ttyUSB0"
-- @param configuration Configuration number to set when GAINER board is connected.
-- Default configuration is 1.
function board:init(serialPort, configuration)
  self.serialPort = serialPort or self.serialPort
  self.configuration = configuration or self.configuration

  assert(native.serial.open(self.serialPort, native.serial.B38400), "Open failed.");
  if self.debug then print("Opened port socket") end

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

---
-- Sets the function to run when interrupt is detected.
-- @param isrName Interrupt name. The only one avarible now is "button".
-- @param isr function name that wil be attached. 
function board:attatchInterrupt(isrName, isr)
  self.interrupts[isrName].isr = isr
end

---
-- Delays the program for s seconds with detection of interrupts.
-- Interrupts will be detected and in any
-- interrupts are attached, they  will run.
-- @param time time in seconds - decimals can be used.
function board:wait(time)
  local ntime = os.clock() + time
  repeat
    _interruptHandler(self, (select(2, coroutine.resume(_serialListener, self.serialInterface))))
  until os.clock() > ntime
end

---
-- Gets digital outuput of GAINER board.
-- @param ... input numbers of GAINER board. For din 0 it will be 1, for
-- all digital inputs it will be 1,2,3,4 and so on.
-- @return output table with booleans. For digital 1 it will be true and for digital 0 it
-- will be false. table index with value is equal to argument number. It can also set a on-board
-- LED when gainer.LED is used as parameter. Order of arguments does not matter.
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

---
-- Turns on or off digital outputs of GAINER board.
-- @param mode State to set on pin or pins. For digital 1 gainer.HIGH is used and for
-- digital 0 gaier.LOW is used.
-- @param ... output numbers of board. For dout 0 it will be 1 and for all all digital
-- outputs it will be 1,2,3,4 and so on.
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
    for _, key in ipairs(pack(...)) do
      if mode == M.HIGH then
        if key == M.LED then
          _sendCommand(commands.ledHigh)
          _waitForResponse(commands.ledHigh, self)
        else
          data = bit.bor(data, bit.lshift(1, key - 1))
        end
      else
        if key == M.LED then
          _sendCommand(commands.ledLow)
          _waitForResponse(commands.ledLow, self)
        else
          data = bit.band(data, bit.bnot(bit.lshift(1, key - 1)))
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

---
-- Sets new configuration of GAINER device.
-- Functions resets GAIENR device ans sets it to a new configuration.
-- State of pins after reset is undefined.
-- @param configuration configutation number.
-- 
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

function board:setMatrix(table)
  if self.configuration ~= 7 then
     print("Warning: board is not in matrix mode 7")
     return
  else
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
      _waitForResponse(commands.setAllAnalog4, self)
    elseif configurations[self.configuration][3] == 8 then
      _sendCommand({
        command = (string.gsub(commands.setAllAnalog8.command, "xxxxxxxxxxxxxxxx", string.upper(payload))),
        responseRegex = commands.setAllAnalog8.responseRegex
      })
      _waitForResponse(commands.setAllAnalog8, self)
    end
    self.lastAnalogOutput = output
  end
end
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
    _waitForResponse(commands.exitContinous, self)
    self.continousMode.status = false
    self.continousMode.command = {}
  else
    print("Warning: board is not in continous mode.")
  end
end

function board:beginAnalogSampling()
  if configurations[self.configuration][1] == 4 then
    _sendCommand(commands.getAllAnalog4C)
    _waitForResponse(commands.getAllAnalog4C, self)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllAnalog4C
  elseif configurations[self.configuration][1] == 8 then
    _sendCommand(commands.getAllAnalog8C)
    _waitForResponse(commands.getAllAnalog8C, self)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllAnalog8C
  else
    print("Error: analog sampling is not supported in current configuration.")
  end
end

function board:beginDigitalSampling()
  if configurations[self.configuration][2] ~= 0 then
    _sendCommand(commands.getAllDigitalC)
    _waitForResponse(commands.getAllDigitalC, self)
    self.continousMode.status = true
    self.continousMode.command = commands.getAllDigitalC
  else
    print("Error: digital sampling is not supported in current configuration.")
  end
end

-- Value from 1 to 16
function board:setSensitivity(value)
  if self.configuration ~= 8 then
    print("Error: Capacitive sensing is not supported in current configuration.")
  else
   _sendCommand({
     command = string.gsub(commands.setSensitivity.command,"x", string.upper(string.format("%x", value - 1))),
     responseRegex = commands.setSensitivity.responseRegex
   })
   _waitForResponse(commands.setSensitivity, self)
  end
end

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

-- value from 1 to 16
function board:setGain(reference, value)
  if reference then
    _sendCommand({
      command = string.gsub(
        string.gsub(commands.setGain.command, "x", string.upper(string.format("%x", value - 1))),
        "n", 1),
      responseRegex = commands.setGain.responseRegex
    })
  else
    _sendCommand({
      command = string.gsub(
        string.gsub(commands.setGain.command, "x", string.upper(string.format("%x", value - 1))),
        "n", 0),
      responseRegex = commands.setGain.responseRegex
    })
  end
  _waitForResponse(commands.setGain, self)
end

function board:getVersion()
  _sendCommand(commands.getVersion)
  local result = _waitForResponse(commands.getVersion, self)
  assert(result, "Error: check board or support of command in configuration")
  return string.match(result, commands.getVersion.responseRegex)
end

-- Boilerplate functions

function board:setDebug(mode)
  self.debug = mode
end

function board:setVerbose(mode)
  self.verbose = mode
end

function board:getLastDigitalInput()
  return self.lastDigitalInput
end

function board:getLastAnalogInput()
  return self.lastAnalogInput
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