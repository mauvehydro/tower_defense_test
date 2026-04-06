---///--------- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------\\\---

---///--------- Variables

local Client = ReplicatedStorage.Client

local Enemies = Client.Enemies

-------------------\\\---

return {
	["Normal"] = {
		Animations = {
			Walk = "rbxassetid://109619371996363"	
		},

		Model = Enemies.Normal,

		Stats = {
			Health = 5,
			Speed = 6
		}
	},

	["Speedy"] = {
		Animations = {
			Walk = "rbxassetid://116746627406950"	
		},

		Model = Enemies.Speedy,

		Stats = {
			Health = 3,
			Speed = 9
		}
	},

	["Strong"] = {
		Animations = {
			Walk = "rbxassetid://109619371996363"	
		},

		Model = Enemies.Strong,

		Stats = {
			Health = 30,
			Speed = 3
		}
	}
}
