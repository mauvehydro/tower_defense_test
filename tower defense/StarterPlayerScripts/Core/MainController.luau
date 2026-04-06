local MainController = {}

--- services \\\

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---///----------

--- variables \\\

local checkpoints = workspace.Checkpoints:GetChildren()

local Client = ReplicatedStorage.Client
local Shared = ReplicatedStorage.Shared
local Utils = ReplicatedStorage.Utils

local BillboardGui = Client.BillboardGui

local Modules = Shared.Modules

local path_data = {}
local total_path_length = 0

---///-----------

--- require \\\

local EnemiesModule = require(Modules.EnemiesModule)
local TowersModule = require(Modules.TowersModule)

local BridgeNet2 = require(Utils.BridgeNet2)

---///---------

--- functions \\\

local Bridge = BridgeNet2.ClientBridge("Bridge")

table.sort(checkpoints, function(a, b)

	return tonumber(a.Name) < tonumber(b.Name)

end)

for i = 1, #checkpoints - 1 do
	local segment_length = (checkpoints[i + 1].Position - checkpoints[i].Position).Magnitude

	total_path_length += segment_length

	path_data[i] = {
		cumulative = total_path_length,
		direction = (checkpoints[i + 1].Position - checkpoints[i].Position).Unit,
		length = segment_length,
		start = checkpoints[i].Position,
		finish = checkpoints[i + 1].Position,
	}
end

local function get_enemy_position(spawn_time, speed)

	local elapsed = (DateTime.now().UnixTimestampMillis - spawn_time) / 1000
	local distance = elapsed * speed

	if distance >= total_path_length then
		return nil, nil
	end

	if distance <= 0 then
		return path_data[1].start, 1
	end

	for i = 1, #path_data do
		if distance <= path_data[i].cumulative then
			local previous = i > 1 and path_data[i - 1].cumulative or 0
			local t = (distance - previous) / path_data[i].length

			return path_data[i].start:Lerp(path_data[i].finish, t), i
		end
	end

	return nil, nil

end

function MainController.initialize()

	local active = {}
	local towers = {}

	local function on_spawn(data)

		local position = Vector3.new(data.position[1], data.position[2], data.position[3])

		local clone = EnemiesModule[data.key].Model:Clone()
		clone.Name = data.id
		clone.Parent = workspace.Enemies
		clone.PrimaryPart.Anchored = true

		local billboard = BillboardGui:Clone()
		billboard.Parent = clone.Head

		billboard.EnemyFrame.EnemyText.Text = data.key
		billboard.EnemyFrame.HealthText.Text = data.health.." / "..data.health

		local offset = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)

		clone:SetPrimaryPartCFrame(CFrame.new(position + offset + Vector3.new(0, 1.25, 0)))

		for _, value in clone:GetChildren() do
			if value:IsA("BasePart") then
				value.CollisionGroup = "Enemies"
			end
		end

		local controller = clone.AnimationController
		local animator = controller.Animator

		local animation = Instance.new("Animation")
		animation.AnimationId = EnemiesModule[data.key].Animations.Walk

		animator:LoadAnimation(animation):Play()

		active[data.id] = {
			key = data.key,
			max = data.health,
			model = clone,
			offset = offset,
			spawn_time = data.spawn_time,
			speed = data.speed,
		}

	end

	local function on_tower(data)

		local position = Vector3.new(data.position[1], data.position[2], data.position[3])

		local clone = TowersModule[data.key].Model:Clone()
		clone.Name = data.id
		clone.Parent = workspace.Towers
		clone.PrimaryPart.Anchored = true

		clone:SetPrimaryPartCFrame(CFrame.new(position))

		for _, value in clone:GetChildren() do
			if value:IsA("BasePart") then
				value.CollisionGroup = "Towers"
			end
		end

		towers[data.id] = {
			current_target = nil,
			key = data.key,
			model = clone,
			position = position,

			stats = {
				damage = data.damage,
				range = data.range,
				cooldown = data.cooldown,
			},
		}

	end

	local function on_attack(data)

		local health = math.max(0, data.health)
		local enemy = active[data.id]

		if not enemy then
			return
		end

		local billboard = enemy.model.Head.BillboardGui.EnemyFrame

		billboard.HealthText.Text = health.." / "..enemy.max

		local ratio = 0

		if enemy.max > 0 then
			ratio = health / enemy.max
		end

		billboard.HealthBar.Size = UDim2.new(ratio, 0, billboard.HealthBar.Size.Y.Scale, billboard.HealthBar.Size.Y.Offset)

	end

	local function on_kill(data)

		local enemy_model = workspace.Enemies:FindFirstChild(data.id)

		if enemy_model then
			enemy_model:Destroy()
		end

		active[data.id] = nil

	end

	local actions = {
		Attack = on_attack,
		Kill = on_kill,
		Spawn = on_spawn,
		Tower = on_tower
	}

	Bridge:Connect(function(data)

		local handler = actions[data.action]

		if handler then
			handler(data)
		end

	end)

	RunService.RenderStepped:Connect(function(delta_time)

		for id, enemy in active do
			local position, segment = get_enemy_position(enemy.spawn_time, enemy.speed)

			if not position then
				active[id] = nil
			else
				local elevated = position + enemy.offset + Vector3.new(0, 1.25, 0)

				local look

				if path_data[segment] then
					look = elevated + path_data[segment].direction
				else
					look = elevated + Vector3.new(0, 0, 1)
				end

				local target_cframe = CFrame.lookAt(elevated, look)
				local current_cframe = enemy.model.PrimaryPart.CFrame
				local smoothed = current_cframe:Lerp(target_cframe, math.clamp(delta_time * 10, 0, 1))

				enemy.model:SetPrimaryPartCFrame(smoothed)
			end
		end

		for id, tower in towers do
			local target_id = tower.current_target

			if target_id and active[target_id] then
				local enemy = active[target_id]

				if enemy.model and enemy.model.PrimaryPart then
					local distance = (enemy.model.PrimaryPart.Position - tower.position).Magnitude

					if distance > tower.stats.range then
						tower.current_target = nil
						target_id = nil
					end
				else
					tower.current_target = nil
					target_id = nil
				end
			else
				tower.current_target = nil
				target_id = nil
			end

			if not tower.current_target then
				local best = nil
				local best_progress = -1

				for enemy_id, enemy in active do
					if enemy.model and enemy.model.PrimaryPart then
						local distance = (enemy.model.PrimaryPart.Position - tower.position).Magnitude

						if distance <= tower.stats.range then
							local elapsed = (DateTime.now().UnixTimestampMillis - enemy.spawn_time) / 1000
							local progress = (elapsed * enemy.speed) / total_path_length

							if progress > best_progress then
								best = enemy_id
								best_progress = progress
							end
						end
					end
				end

				if best then
					tower.current_target = best
					target_id = best
				end
			end

			if target_id then
				local enemy = active[target_id]

				if enemy and enemy.model and enemy.model.PrimaryPart then
					local position = tower.model.PrimaryPart.Position
					local enemy_position = enemy.model.PrimaryPart.Position

					local look = Vector3.new(enemy_position.X, position.Y, enemy_position.Z)

					local current_cframe = tower.model.PrimaryPart.CFrame
					local target_cframe = CFrame.lookAt(position, look)

					local alpha = math.clamp(delta_time * 9, 0, 1)

					tower.model:SetPrimaryPartCFrame(current_cframe:Lerp(target_cframe, alpha))
				end
			end
		end

	end)

end

---///-----------

return MainController
