local M = {}
-- Command, response regex and if continuous then true
M.gainer = {}
M.gainer.commands = {
  [1] =             {command = "KONFIGURATION_1*", responseRegex = "KONFIGURATION_1%*", errorRegex = "!%*"},
  [2] =             {command = "KONFIGURATION_2*", responseRegex = "KONFIGURATION_2%*", errorRegex = "!%*"},
  reset =           {command = "Q*", responseRegex = "Q%*", errorRegex = "!%*"},
  ledHigh =         {command = "h*", responseRegex = "h%*", errorRegex = "%[h%]!%*"},
  ledLow =          {command = "l*", responseRegex = "l%*", errorRegex = "%[l%]!%*"},
  getAllDigital =   {command = "R*", responseRegex = "R%d%d%d%d%*$", errorRegex = "!%*", dataRetrieveRegex = "(%d%d%d%d)"},
  
  getAllAnalog4 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%*", dataRetrieveRegex = "(%x%x)"},
  getAllAnalog8 =   {command = "I*", responseRegex = "I%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%*", dataRetrieveRegex = "(%x%x)"},
  -- Continuous mode responses doesn't have stars
  getAllAnalog4C =   {command = "i*", responseRegex = "i(%x%x)(%x%x)(%x%x)(%x%x)", dataRetrieveRegex = "(%x%x)"}, 
  }
  
M.gainer.interrupts = {
{ name = "button", regex = ".*([N,F])%*", data = "F" }
}

return M