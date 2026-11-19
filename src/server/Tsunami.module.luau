-- Tsunami: the threat on a timer. Every so often a wall of water sweeps the
-- lane from the shop end to the shrine end. Standing on any base plot is
-- safe; anyone caught in the open is flung, hurt, and drops whatever brainrot
-- they were carrying — and the belt is washed clean.
-- One job: the wave — warning, sweeping, hitting.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Tsunami = {}

local PERIOD = 85 -- seconds between waves
local WARNING = 10 -- seconds of warning before a wave
local WAVE_SPEED = 30
local WAVE_START_X = -140
local WAVE_END_X = 145
local HIT_DAMAGE = 35

local plots = nil
local steal = nil
local conveyor = nil
local alertRemote: RemoteEvent? = nil

function Tsunami.Init(deps)
	plots = deps.Plots
	steal = deps.Steal
	conveyor = deps.Conveyor
	alertRemote = deps.AlertRemote
end

local function buildWave(): Part
	local wave = Instance.new("Part")
	wave.Name = "TsunamiWave"
	wave.Size = Vector3.new(24, 26, 52)
	wave.Color = Color3.fromRGB(60, 150, 235)
	wave.Transparency = 0.35
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.Position = Vector3.new(WAVE_START_X, 11, 0)
	wave.Parent = Workspace
	return wave
end

local function sweepWave()
	conveyor.ClearLane()
	local wave = buildWave()
	local hitDone: { [Player]: boolean } = {}
	local x = WAVE_START_X
	while x <= WAVE_END_X do
		local dt = RunService.Heartbeat:Wait()
		x += WAVE_SPEED * dt
		wave.Position = Vector3.new(x, 11, 0)
		-- Catch anyone in the open within the wave's front.
		for _, player in ipairs(Players:GetPlayers()) do
			if hitDone[player] then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				if math.abs(root.Position.X - x) < 14 and math.abs(root.Position.Z) < 26 then
					if not plots.IsOnAnyBase(root.Position) then
						hitDone[player] = true
						steal.DropCarried(player)
						humanoid:TakeDamage(HIT_DAMAGE)
						root.AssemblyLinearVelocity = Vector3.new(55, 42, 0)
					end
				end
			end
		end
	end
	wave:Destroy()
end

function Tsunami.Start()
	task.spawn(function()
		while true do
			task.wait(PERIOD - WARNING)
			if alertRemote then
				alertRemote:FireAllClients(WARNING)
			end
			task.wait(WARNING)
			if alertRemote then
				alertRemote:FireAllClients(0)
			end
			sweepWave()
		end
	end)
end

return Tsunami
