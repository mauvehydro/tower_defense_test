local MainController = {}
MainController.__index = MainController

--- services \\\

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

---///----------

--- variables \\\

local checkpoints = workspace.Checkpoints:GetChildren()

local Shared = ReplicatedStorage.Shared
local Utils = ReplicatedStorage.Utils
local Cache = ServerStorage.Cache

local Modules = Shared.Modules

local path_data = {}
local total_path_length = 0

---///-----------

--- require \\\

local EnemiesModule = require(Modules.EnemiesModule)
local TowersModule = require(Modules.TowersModule)

local BridgeNet2 = require(Utils.BridgeNet2)

local IDsCache = require(Cache.IDsCache)

---///---------

--- functions \\\

local Bridge = BridgeNet2.ServerBridge("Bridge")

table.sort(checkpoints, function(a, b)

	return tonumber(a.Name) < tonumber(b.Name)

end)

for i = 1, #checkpoints - 1 do
	local segment_length = (checkpoints[i + 1].Position - checkpoints[i].Position).Magnitude

	total_path_length += segment_length

	path_data[i] = {
		cumulative = total_path_length,
		length = segment_length,
		start = checkpoints[i].Position,
		finish = checkpoints[i + 1].Position
	}
end

local function deep_copy(original)

	if type(original) ~= "table" then
		return original
	end

	local copy = {}

	for key, value in original do
		copy[key] = deep_copy(value)
	end

	return copy

end

local function get_enemy_position(spawn_time, speed)

	local elapsed = (DateTime.now().UnixTimestampMillis - spawn_time) / 1000
	local distance = elapsed * speed

	if distance >= total_path_length then
		return nil, 1
	end

	if distance <= 0 then
		return path_data[1].start, 0
	end

	for i = 1, #path_data do
		if distance <= path_data[i].cumulative then
			local previous = i > 1 and path_data[i - 1].cumulative or 0
			local t = (distance - previous) / path_data[i].length

			return path_data[i].start:Lerp(path_data[i].finish, t), (previous + t * path_data[i].length) / total_path_length
		end
	end

	return nil, 1

end

local function validate_placement(position, tower_key)

	if not TowersModule[tower_key] then
		return false
	end

	local params = RaycastParams.new()

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {
		workspace.Enemies,
		workspace.Towers
	}

	local origin = position + Vector3.new(0, 5, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -10, 0), params)

	if not result or not result.Instance then
		return false
	end

	if result.Instance:GetAttribute("Place") ~= true then
		return false
	end

	return true

end

function MainController:enemy()

	local keys = {}

	for key in EnemiesModule do
		table.insert(keys, key)
	end

	local random_key = keys[math.random(1, #keys)]
	local selected = EnemiesModule[random_key]

	table.insert(self.queue, {
		key = random_key,
		stats = deep_copy(selected.Stats),
	})

	if not self.spawning then
		self.spawning = true

		task.spawn(function()

			while #self.queue > 0 do
				local data = table.remove(self.queue, 1)

				local id = IDsCache.generate()
				local spawn_time = DateTime.now().UnixTimestampMillis

				self.enemies[id] = {
					key = data.key,
					spawn_time = spawn_time,
					stats = data.stats,
				}

				local position = checkpoints[1].Position

				Bridge:Fire(BridgeNet2.AllPlayers(), {
					action = "Spawn",
					id = id,
					key = data.key,
					spawn_time = spawn_time,
					speed = data.stats.Speed,
					health = data.stats.Health,

					position = {
						position.X,
						position.Y,
						position.Z,
					},
				})
			end

			self.spawning = false

		end)
	end

end

function MainController:tower(position, tower_key)

	local id = IDsCache.generate()
	local stats = deep_copy(TowersModule[tower_key].Stats)

	self.towers[id] = {
		key = tower_key,
		last_attack = DateTime.now().UnixTimestampMillis,
		position = position,
		stats = stats,
		in_range = {},
		target = nil,
	}

	Bridge:Fire(BridgeNet2.AllPlayers(), {
		action = "Tower",
		id = id,
		key = tower_key,

		position = {
			position.X,
			position.Y,
			position.Z,
		},

		damage = stats.Damage,
		range = stats.Range,
		cooldown = stats.Cooldown,
	})

end

function MainController.initialize()

	local self = setmetatable({
		enemies = {},
		queue = {},
		towers = {},
	}, MainController)

	Bridge:Connect(function(player, data)

		if data.action == "Spawn" then
			self:enemy()
		elseif data.action == "Placed" then
			if not data.position or not data.tower then
				return
			end

			local position = Vector3.new(data.position[1], data.position[2], data.position[3])

			if not validate_placement(position, data.tower) then
				return
			end

			if player.leaderstats.Money.Value >= TowersModule[data.tower].Price then
				self:tower(position, data.tower)

				player.leaderstats.Money.Value -= TowersModule[data.tower].Price
			end
		end

	end)

	self:connect()

	return self

end

function MainController:connect()

	RunService.Heartbeat:Connect(function()

		local now = DateTime.now().UnixTimestampMillis

		for id, enemy in self.enemies do
			local position, progress = get_enemy_position(enemy.spawn_time, enemy.stats.Speed)

			if not position then
				Bridge:Fire(BridgeNet2.AllPlayers(), {
					action = "Kill",
					id = id,
				})

				IDsCache.clean(id)

				self.enemies[id] = nil

				for _, current_tower in self.towers do
					current_tower.in_range[id] = nil

					if id == current_tower.target then
						current_tower.target = nil
					end
				end
			else
				enemy.position = position
				enemy.progress = progress

				for _, current_tower in self.towers do
					local distance = (position - current_tower.position).Magnitude

					if distance <= current_tower.stats.Range then
						current_tower.in_range[id] = true
					else
						if current_tower.in_range[id] then
							current_tower.in_range[id] = nil

							if id == current_tower.target then
								current_tower.target = nil
							end
						end
					end
				end
			end
		end

		for id, current_tower in self.towers do
			local best
			local best_progress = -math.huge

			for enemy_id in current_tower.in_range do
				local enemy = self.enemies[enemy_id]

				if enemy then
					if enemy.progress > best_progress then
						best = enemy_id
						best_progress = enemy.progress
					end
				else
					current_tower.in_range[enemy_id] = nil

					if current_tower.target == enemy_id then
						current_tower.target = nil
					end
				end
			end

			if best ~= current_tower.target then
				current_tower.target = best
			end

			if now - current_tower.last_attack >= current_tower.stats.Cooldown * 1000 then
				if current_tower.target then
					local enemy = self.enemies[current_tower.target]

					if enemy then
						enemy.stats.Health = math.max(0, enemy.stats.Health - current_tower.stats.Damage)

						Bridge:Fire(BridgeNet2.AllPlayers(), {
							action = "Attack",
							id = current_tower.target,
							health = enemy.stats.Health,
						})

						if enemy.stats.Health <= 0 then
							Bridge:Fire(BridgeNet2.AllPlayers(), {
								action = "Kill",
								id = current_tower.target,
							})

							IDsCache.clean(current_tower.target)

							local dead_id = current_tower.target

							self.enemies[dead_id] = nil

							for _, other_tower in self.towers do
								other_tower.in_range[dead_id] = nil

								if other_tower.target == dead_id then
									other_tower.target = nil
								end
							end
						end
					else
						current_tower.target = nil
					end
				end

				current_tower.last_attack = now
			end
		end

	end)

end

---///-----------

return MainController
