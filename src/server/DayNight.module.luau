-- DayNight: the world's clock. A full cycle is 6 minutes (4 of day,
-- 2 of night), driven entirely on the server: it steers
-- Lighting.ClockTime, fades brightness and ambient as darkness falls,
-- switches the street lamps and the lane's neon strips on at night,
-- and publishes the phase (Day/Night, progress, day counter) as
-- Workspace attributes for the HUD. At every DAWN the conveyor is
-- restocked — unsold belt stock despawns, a fresh lineup rides in,
-- and everyone is told. Brainrots already placed on bases are never
-- touched. The tsunami keeps its own independent timer.
-- One job: the cycle.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local DayNight = {}

local DAY_AMBIENT = Color3.fromRGB(120, 120, 130)
local NIGHT_AMBIENT = Color3.fromRGB(42, 48, 78)
local DAY_BRIGHTNESS = 2.4
local NIGHT_BRIGHTNESS = 1.1

local conveyor = nil
local broadcast: ((string) -> ())? = nil

local lampHeads: { BasePart } = {}
local glowStrips: { BasePart } = {}

local function collectGlowTargets()
	local decor = Workspace:FindFirstChild("Decor")
	if decor then
		for _, child in ipairs(decor:GetChildren()) do
			if string.sub(child.Name, 1, 4) == "Lamp" then
				local head = child:FindFirstChild("Head")
				if head then
					local light = Instance.new("PointLight")
					light.Name = "LampGlow"
					light.Color = Color3.fromRGB(255, 226, 150)
					light.Range = 20
					light.Brightness = 0
					light.Parent = head
					table.insert(lampHeads, head)
				end
			end
		end
	end
	local lane = Workspace:FindFirstChild("Lane")
	if lane then
		for _, name in ipairs({ "GlowStripN", "GlowStripS" }) do
			local strip = lane:FindFirstChild(name)
			if strip then
				table.insert(glowStrips, strip)
			end
		end
	end
	local treadmill = Workspace:FindFirstChild("Treadmill")
	local screen = treadmill and treadmill:FindFirstChild("ConsoleScreen")
	if screen then
		table.insert(glowStrips, screen)
	end
end

local function setGlow(darkness: number)
	local on = darkness > 0.25
	for _, head in ipairs(lampHeads) do
		head.Material = if on then Enum.Material.Neon else Enum.Material.Plastic
		local light = head:FindFirstChild("LampGlow")
		if light then
			light.Brightness = if on then 1.8 else 0
		end
	end
	for _, strip in ipairs(glowStrips) do
		strip.Material = if on then Enum.Material.Neon else Enum.Material.Plastic
	end
end

function DayNight.Init(deps)
	conveyor = deps.Conveyor
	broadcast = deps.Broadcast
	collectGlowTargets()
	Workspace:SetAttribute("DayNumber", 1)
	Workspace:SetAttribute("PhaseName", "Day")
	Workspace:SetAttribute("PhaseProgress", 0)
end

function DayNight.Start()
	local dayLength = GameConfig.DaySeconds
	local nightLength = GameConfig.NightSeconds
	local cycle = dayLength + nightLength
	task.spawn(function()
		local elapsed = 0
		local day = 1
		local wasNight = false
		while true do
			local dt = task.wait(0.5)
			elapsed += dt
			local t = elapsed % cycle
			local isNight = t >= dayLength

			-- Dawn: the night -> day wrap. Restock the belt, bump the
			-- counter, tell everyone.
			if wasNight and not isNight then
				day += 1
				Workspace:SetAttribute("DayNumber", day)
				if conveyor then
					conveyor.Restock()
				end
				if broadcast then
					broadcast("☀️ Day " .. day .. " — a new day! The conveyor has been restocked.")
				end
			end
			wasNight = isNight

			-- Clock: day runs 6.5 -> 17.5, night runs 17.5 -> 30.5 (= 6.5).
			local clock: number
			local darkness: number
			local phaseProgress: number
			if not isNight then
				local frac = t / dayLength
				clock = 6.5 + frac * 11
				darkness = 0
				phaseProgress = frac
			else
				local frac = (t - dayLength) / nightLength
				clock = 17.5 + frac * 13
				-- Deepest dark in the middle of the night.
				darkness = math.sin(math.pi * frac)
				phaseProgress = frac
			end
			Lighting.ClockTime = clock % 24
			Lighting.Brightness = DAY_BRIGHTNESS + (NIGHT_BRIGHTNESS - DAY_BRIGHTNESS) * darkness
			Lighting.Ambient = DAY_AMBIENT:Lerp(NIGHT_AMBIENT, darkness)
			setGlow(darkness)

			Workspace:SetAttribute("PhaseName", if isNight then "Night" else "Day")
			Workspace:SetAttribute("PhaseProgress", phaseProgress)
		end
	end)
end

return DayNight
