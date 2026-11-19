-- Treadmill: the gym station near spawn. Stand on the belt and run in
-- place: a progress meter fills (faster with a higher treadmill level
-- and a higher personal speed), and every completed run grants a random
-- brainrot rolled from the treadmill's rarity table — Common-Rare at
-- level 1, with Epic, Legendary and finally Mythic unlocking as the
-- station levels up. Dewa Langit is never on this table. If the
-- runner's pen is full, the creature converts to Coin at half price.
-- One job: the run loop and the station's upgrade prompt. Fully
-- server-authoritative: the client only draws the meter it is sent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

local Treadmill = {}

local TICK = 0.2

local economy = nil
local plots = nil
local notify: ((Player, string) -> ())? = nil
local progressRemote: RemoteEvent? = nil
local effectiveSpeed: ((Player) -> number)? = nil

local belt: BasePart? = nil
local rng = Random.new()
local progress: { [Player]: number } = {}

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

function Treadmill.Init(deps)
	economy = deps.Economy
	plots = deps.Plots
	notify = deps.Notify
	progressRemote = deps.ProgressRemote
	effectiveSpeed = deps.EffectiveSpeed

	local station = Workspace:WaitForChild("Treadmill")
	belt = station:WaitForChild("Belt")

	local post = station:FindFirstChild("UpgradePost")
	if post then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TreadmillUpgradePrompt"
		prompt.ActionText = "Upgrade Treadmill"
		prompt.ObjectText = "Better rolls, faster runs"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = post
		prompt.Triggered:Connect(function(player)
			Treadmill.BuyUpgrade(player)
		end)
	end
end

-- Sells the next treadmill level (levels are per-player; the station
-- itself is shared).
function Treadmill.BuyUpgrade(player: Player)
	local entry = economy.Get(player)
	if not entry then
		return
	end
	local level = entry.TreadmillLevel
	if level >= GameConfig.TreadmillMaxLevel then
		tell(player, "Your treadmill is already MAX level!")
		return
	end
	local cost = GameConfig.TreadmillUpgradeCost(level)
	if not economy.TrySpend(player, cost) then
		tell(player, "Treadmill Lv." .. (level + 1) .. " needs " .. BrainrotDefs.FormatCash(cost) .. " Coin!")
		return
	end
	economy.SetTreadmillLevel(player, level + 1)
	local note = "Treadmill upgraded to Lv." .. (level + 1) .. "!"
	if level + 1 == 3 then
		note ..= " Epic brainrots can now drop!"
	elseif level + 1 == 5 then
		note ..= " Legendary brainrots can now drop!"
	elseif level + 1 == 8 then
		note ..= " MYTHIC brainrots can now drop!"
	end
	tell(player, note)
end

local function onBelt(player: Player): boolean
	if not belt then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local top = belt.Position.Y + belt.Size.Y / 2
	return math.abs(root.Position.X - belt.Position.X) <= belt.Size.X / 2 + 1
		and math.abs(root.Position.Z - belt.Position.Z) <= belt.Size.Z / 2 + 1
		and root.Position.Y >= top - 1
		and root.Position.Y <= top + 5
end

local function grantRun(player: Player)
	local entry = economy.Get(player)
	if not entry then
		return
	end
	local def = BrainrotDefs.RollWeighted(rng, GameConfig.TreadmillFactors(entry.TreadmillLevel))
	local pad = plots.FreePad(player)
	if pad then
		local model = Factory.Build(def, CFrame.new(pad.Position + Vector3.new(0, 2, 0)))
		plots.PlaceOnPad(player, def, model, pad)
		tell(player, "🏃 Treadmill reward: " .. def.Name .. " (" .. def.Rarity .. ")!")
	else
		local coin = math.floor(def.Price / 2)
		economy.AddCoin(player, coin)
		tell(player, "🏃 You won " .. def.Name .. " but your pen is full — converted to " .. BrainrotDefs.FormatCash(coin) .. " Coin!")
	end
end

function Treadmill.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				local entry = economy.Get(player)
				if not entry then
					continue
				end
				if onBelt(player) then
					local fillSeconds = GameConfig.TreadmillFillSeconds(entry.TreadmillLevel)
					local speedFactor = (effectiveSpeed and effectiveSpeed(player) or 16) / 16
					local next_ = (progress[player] or 0) + (TICK / fillSeconds) * speedFactor
					if next_ >= 1 then
						progress[player] = 0
						if progressRemote then
							progressRemote:FireClient(player, 0)
						end
						grantRun(player)
					else
						progress[player] = next_
						if progressRemote then
							progressRemote:FireClient(player, next_)
						end
					end
				elseif progress[player] and progress[player] > 0 then
					progress[player] = 0
					if progressRemote then
						progressRemote:FireClient(player, 0)
					end
				end
			end
		end
	end)
end

return Treadmill
