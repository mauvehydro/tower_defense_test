--- services \\\

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer").StarterPlayerScripts

---///----------

--- variables \\\

local Remotes = ReplicatedStorage.Remotes
local Core = StarterPlayerScripts.Core

local Loaded = Remotes.Loaded

---///-----------

--- require \\\

local MainController = require(Core.MainController)
local MenuController = require(Core.MenuController)

---///---------

--- functions \\\

return function()

	MainController.initialize()
	MenuController.initialize()

	Loaded:FireServer()

end

---///-----------
