local MenuController = {}

--- services \\\

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

---///----------

--- variables \\\

local camera = workspace.CurrentCamera

local player = Players.LocalPlayer
local Client = ReplicatedStorage.Client
local Shared = ReplicatedStorage.Shared
local Utils = ReplicatedStorage.Utils

local Towers = Client.Towers
local Modules = Shared.Modules

local active
local connection
local result
local tower
local range_indicator
local ground_y = 0

local current = CFrame.new()
local target = CFrame.new()

local degrees = 10
local scale = 0.1

local equipped = {
	[1] = "Scout",
}

local position = Vector3.new()
local target_position = Vector3.new()
local smooth = Vector3.new()

local rotation = 0.15
local speed = 0.15

---///-----------

--- require \\\

local TowersModule = require(Modules.TowersModule)

local BridgeNet2 = require(Utils.BridgeNet2)
local Observers = require(Utils.Observers)

---///---------

--- functions \\\

local Bridge = BridgeNet2.ClientBridge("Bridge")

local function destroy_range()

	if range_indicator then
		range_indicator:Destroy()
		range_indicator = nil
	end

end

local function create_range(range)

	destroy_range()

	local indicator = Instance.new("Part", workspace)
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.CanQuery = false
	indicator.CanTouch = false
	indicator.CastShadow = false
	indicator.Color = Color3.fromRGB(30, 90, 45)
	indicator.Material = Enum.Material.ForceField
	indicator.Name = "RangeIndicator"
	indicator.Size = Vector3.new(0.3, range * 2, range * 2)
	indicator.Shape = Enum.PartType.Cylinder
	indicator.Transparency = 0

	range_indicator = indicator

end

local function disconnect()

	if connection then
		connection:Disconnect()
		connection = nil
	end

	if tower then
		tower:Destroy()
		tower = nil
	end

	destroy_range()

	active = nil

end

local function raycast(exclude)

	local location = UserInputService:GetMouseLocation()
	local params = RaycastParams.new()
	local ray = camera:ViewportPointToRay(location.X, location.Y)

	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	return workspace:Raycast(ray.Origin, ray.Direction * 512, params)

end

local function connect(frame)

	if active == frame then
		disconnect()

		return
	end

	active = frame

	if connection then
		connection:Disconnect()
		connection = nil
	end

	if tower then
		tower:Destroy()
		tower = nil
	end

	destroy_range()

	local index = tonumber((string.gsub(frame, "Frame$", "")))
	local tower_key = equipped[index]

	if not tower_key then
		return
	end

	tower = Towers[tower_key]:Clone()
	tower.Parent = workspace
	tower.PrimaryPart.Anchored = true

	for _, value in tower:GetChildren() do
		if value:IsA("BasePart") then
			value.CollisionGroup = "Towers"
		end
	end

	local initial = raycast({ tower })

	if initial and initial.Instance then
		local x = initial.Position.X
		local y = initial.Position.Y + 1.5
		local z = initial.Position.Z

		tower:SetPrimaryPartCFrame(CFrame.new(x, y, z))

		ground_y = initial.Position.Y
	end

	current = CFrame.new()
	target = CFrame.new()

	position = tower.PrimaryPart.Position
	target_position = position
	smooth = Vector3.new()

	local range = TowersModule[tower_key].Stats.Range

	create_range(range)

	if range_indicator then
		range_indicator.CFrame = CFrame.new(position.X, ground_y - (0.3 / 2), position.Z) * CFrame.Angles(0, math.rad(-90), math.rad(-90))
	end

	connection = RunService.RenderStepped:Connect(function(delta_time)

		result = raycast({
			tower,
			range_indicator
		})

		if result and result.Instance then
			if result.Instance:GetAttribute("Place") == true then
				range_indicator.Color = Color3.fromRGB(45, 120, 60)
			else
				range_indicator.Color = Color3.fromRGB(150, 30, 60)
			end

			local x = result.Position.X
			local y = result.Position.Y + 1.5
			local z = result.Position.Z

			target_position = Vector3.new(x, y, z)
			ground_y = result.Position.Y
		end

		position = position:Lerp(target_position, speed)
		current = current:Lerp(target, rotation)

		local desired = (target_position - position) / math.max(delta_time, 1 / 60)

		smooth = smooth:Lerp(desired, 0.3)

		local base = CFrame.new(position) * current
		local velocity = base:VectorToObjectSpace(smooth)

		local tilt_x = math.clamp(-velocity.Z * scale, -degrees, degrees)
		local tilt_z = math.clamp(velocity.X * scale, -degrees, degrees)

		local final = base * CFrame.Angles(math.rad(tilt_x), 0, math.rad(tilt_z))

		tower:SetPrimaryPartCFrame(final)

		if range_indicator then
			range_indicator.Position = Vector3.new(position.X, ground_y + (range_indicator.Size.X / 2) + 0.05, position.Z)
		end

	end)

end

function MenuController.initialize()

	Observers.observeChildren(player.PlayerGui, function(gui)

		if gui.Name == "EnemiesGui" then
			gui.EnemiesFrame.SpawnButton.MouseButton1Click:Connect(function()

				Bridge:Fire({
					action = "Spawn"
				})

			end)

			workspace.Enemies.ChildAdded:Connect(function()

				gui.EnemiesFrame.RemainingText.Text = #workspace.Enemies:GetChildren()

			end)

			workspace.Enemies.ChildRemoved:Connect(function()

				gui.EnemiesFrame.RemainingText.Text = #workspace.Enemies:GetChildren()

			end)
		elseif gui.Name == "EquippedGui" then
			for slot, tower_key in equipped do
				local frame = gui.EquippedFrame[slot.."Frame"]

				frame.PriceText.Text = TowersModule[tower_key].Price.."$"

				local viewport = frame.ViewportFrame

				local clone = Towers[tower_key]:Clone()
				clone.Parent = viewport

				local viewport_camera = Instance.new("Camera", viewport)

				viewport.CurrentCamera = viewport_camera

				viewport_camera.CFrame = CFrame.new(0, 0, -3) * CFrame.Angles(math.rad(0), math.rad(-180), math.rad(0))
			end

			for _, frame in gui.EquippedFrame:GetChildren() do
				if frame:IsA("UIListLayout") then
					continue
				end

				frame.EquipButton.MouseButton1Click:Connect(function()

					connect(frame.Name)

				end)
			end
		end

	end)

	UserInputService.InputBegan:Connect(function(input, game_processed_event)

		if game_processed_event then
			return
		end

		if input.KeyCode == Enum.KeyCode.One then
			connect("1Frame")
		elseif input.KeyCode == Enum.KeyCode.Two then
			connect("2Frame")
		elseif input.KeyCode == Enum.KeyCode.Three then
			connect("3Frame")
		elseif input.KeyCode == Enum.KeyCode.Four then
			connect("4Frame")
		elseif input.KeyCode == Enum.KeyCode.Five then
			connect("5Frame")
		end

		if tower then
			if input.KeyCode == Enum.KeyCode.Q then
				disconnect()
			elseif input.KeyCode == Enum.KeyCode.R then
				target = target * CFrame.Angles(0, math.rad(90), 0)
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 and result and result.Instance and result.Instance:GetAttribute("Place") == true then
				if connection then
					connection:Disconnect()
					connection = nil
				end

				local tower_position = tower.PrimaryPart.Position

				Bridge:Fire({
					action = "Placed",

					position = {
						tower_position.X,
						tower_position.Y,
						tower_position.Z
					},

					tower = tower.Name,
				})

				tower:Destroy()

				tower = nil

				destroy_range()

				active = nil
			end
		end

	end)

end

---///-----------

return MenuController
