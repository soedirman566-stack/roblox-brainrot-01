-- Steal: the crime system. Every placed brainrot carries a Steal prompt;
-- grabbing one hoists it over the thief's head, and the theft only counts
-- when the thief carries it home to their own plot. The victim can rescue
-- it by catching the thief, and a locked base refuses all thieves.
-- One job: carries — starting them, shadowing the thief, settling them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Steal = {}

local CARRY_HEIGHT = 5.2
local RESCUE_DISTANCE = 6.5
local CARRY_WALKSPEED = 13
local NORMAL_WALKSPEED = 16

local plots = nil
local economy = nil
local notify: ((Player, string) -> ())? = nil

local carriedByThief: { [Player]: any } = {}

function Steal.Init(deps)
	plots = deps.Plots
	economy = deps.Economy
	notify = deps.Notify
end

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

local function setCarrying(player: Player, record)
	carriedByThief[player] = record
	player:SetAttribute("Carrying", record ~= nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if record then CARRY_WALKSPEED else NORMAL_WALKSPEED
	end
end

-- Puts a carried brainrot back on the pad it was stolen from.
local function returnToPad(record)
	local pad = record.Pad
	record.CarriedBy = nil
	if pad and record.Model then
		local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
		local facing = if pad.Position.Z < 0 then top + Vector3.new(0, 0, 10) else top - Vector3.new(0, 0, 10)
		record.Model:PivotTo(CFrame.lookAt(top, facing))
	end
end

-- Ends a carry without a transfer: the brainrot goes home to its pad.
function Steal.CancelCarry(thief: Player)
	local record = carriedByThief[thief]
	if not record then
		return
	end
	setCarrying(thief, nil)
	returnToPad(record)
end

-- Settles a successful theft: the record changes owner and pad.
local function completeTheft(thief: Player, record)
	local victim = record.Player
	local pad = plots.FreePad(thief)
	setCarrying(thief, nil)
	if not pad then
		returnToPad(record)
		return
	end
	plots.DetachRecord(record, false)
	plots.PlaceOnPad(thief, record.Def, record.Model, pad)
	tell(thief, "Stole " .. record.Def.Name .. " from " .. victim.DisplayName .. "!")
	tell(victim, thief.DisplayName .. " stole your " .. record.Def.Name .. "!")
end

-- The carry loop: the model shadows the thief until the theft settles,
-- the victim rescues it, or the thief dies, leaves or drops it.
local function runCarry(thief: Player, record)
	local victim = record.Player
	while record.CarriedBy == thief and carriedByThief[thief] == record do
		if not record.Model or record.Model.Parent == nil then
			-- The victim left and their brainrots were cleaned up mid-carry.
			setCarrying(thief, nil)
			record.CarriedBy = nil
			return
		end
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or thief.Parent ~= Players then
			Steal.CancelCarry(thief)
			return
		end
		record.Model:PivotTo(CFrame.new(root.Position + Vector3.new(0, CARRY_HEIGHT, 0)))

		-- Home safe: standing on the thief's own plot settles the theft.
		if plots.IsOnOwnBase(thief, root.Position) then
			completeTheft(thief, record)
			return
		end
		-- Caught: the victim reaching the thief rescues the brainrot.
		local victimCharacter = victim.Character
		local victimRoot = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
		if victimRoot and (victimRoot.Position - root.Position).Magnitude <= RESCUE_DISTANCE then
			Steal.CancelCarry(thief)
			tell(thief, victim.DisplayName .. " caught you! The brainrot ran home.")
			tell(victim, "You rescued your " .. record.Def.Name .. "!")
			return
		end
		RunService.Heartbeat:Wait()
	end
end

local function onStealPrompt(record, thief: Player)
	if thief == record.Player then
		return
	end
	if record.CarriedBy then
		return
	end
	if carriedByThief[thief] then
		tell(thief, "You are already carrying a brainrot!")
		return
	end
	if plots.IsLocked(record.Player) then
		tell(thief, "That base is locked — try again later!")
		return
	end
	if not plots.FreePad(thief) then
		tell(thief, "Your base is full!")
		return
	end
	record.CarriedBy = thief
	setCarrying(thief, record)
	tell(thief, "You grabbed " .. record.Def.Name .. "! Carry it to YOUR base!")
	tell(record.Player, thief.DisplayName .. " is stealing your " .. record.Def.Name .. "!")
	task.spawn(runCarry, thief, record)
end

-- Called by PlotManager (through init.server) for every placed brainrot.
function Steal.AttachPrompt(record)
	local body = record.Model:FindFirstChild("Body")
	if not body then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = record.Def.Name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		onStealPrompt(record, player)
	end)
end

-- What a player is carrying right now, if anything.
function Steal.GetCarriedRecord(player: Player)
	return carriedByThief[player]
end

-- Forces a drop (tsunami hit, rebirth, leaving): the brainrot runs home.
function Steal.DropCarried(player: Player)
	Steal.CancelCarry(player)
end

return Steal
