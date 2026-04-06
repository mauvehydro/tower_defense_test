--- services \\\

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---///----------

--- variables \\\

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Initialized = Remotes:WaitForChild("Initialized")

---///-----------

--- functions \\\

Initialized.OnClientEvent:Once(function()

	local assets = game:GetDescendants()

	for _, asset in assets do
		ContentProvider:PreloadAsync({
			asset
		})
	end

	require(script.Framework)()

end)

---///-----------
