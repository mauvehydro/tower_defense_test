--- services \\\

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---///----------

--- variables \\\

local Client = ReplicatedStorage.Client
local Remotes = ReplicatedStorage.Remotes

local GUIs = Client.GUIs

local Initialized = Remotes.Initialized
local Loaded = Remotes.Loaded

---///-----------

--- functions \\\

return function(player)

	if not player.Character then
		player.CharacterAdded:Wait()
	end

	player:SetAttribute("Connected", false)

	for _, value in player.Character:GetChildren() do
		if value:IsA("BasePart") then
			value.CollisionGroup = "Character"
		end
	end

	local leaderstats = Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"

	local money = Instance.new("NumberValue", leaderstats)
	money.Name = "Money"
	money.Value = 999999999

	local connection

	connection = Loaded.OnServerEvent:Connect(function(other)

		if player.UserId == other.UserId then
			connection:Disconnect()
			connection = nil

			player:SetAttribute("Connected", true)

			player.Character.Humanoid.JumpHeight = 7.2
			player.Character.Humanoid.WalkSpeed = 16

			local clone = GUIs.EnemiesGui:Clone()
			clone.Parent = player.PlayerGui

			clone = GUIs.EquippedGui:Clone()
			clone.Parent = player.PlayerGui
		end

	end)

	Initialized:FireClient(player)

end
