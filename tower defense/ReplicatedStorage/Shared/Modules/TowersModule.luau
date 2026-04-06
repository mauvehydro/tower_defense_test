---///--------- Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------\\\---

---///--------- Variables

local Client = ReplicatedStorage.Client

local Towers = Client.Towers

-------------------\\\---

return {
	["Scout"] = {
		Model = Towers.Scout,

		Price = 100,

		Stats = {
			Cooldown = 0.5,
			Damage = 1,
			Range = 18
		}
	}
}
