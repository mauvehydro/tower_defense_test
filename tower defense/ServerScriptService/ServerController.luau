--- services \\\

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

---///----------

--- variables \\\

local Core = ServerScriptService.Core

---///-----------

--- require \\\

local PlayerAdded = require(script.PlayerAdded)

local MainController = require(Core.MainController)

---///---------

--- functions \\\

MainController.initialize()

Players.PlayerAdded:Connect(PlayerAdded)

---///-----------
