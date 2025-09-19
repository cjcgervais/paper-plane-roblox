-- PaperPlaneSpawner.server.lua  (v1.3.6 "Golden Master+")
-- Server-authoritative paper plane with corrected AoA lift and seat-aware UX.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")

-- ===== TUNABLES ============================================================
local DEV_DIAG          = false
local USE_RIDER_WELD    = true
local SIT_TIMEOUT_SEC   = 2.0
local PHYS_HZ           = 60

-- Forces / model
local THRUST_SLOW       = 4200
local THRUST_FAST       = 12500
local MAX_SPEED         = 200
local LIFT_K            = 35          -- base lift vs. speed
local LIFT_PITCH_SCALAR = 2.5         -- extra lift from pitch-up (AoA)
local DRAG_K            = 0.014
local LOWSPEED_THRUST   = 0.25
local LOWSPEED_REF_V    = 80
local STALL_SPEED       = 20
local STALL_PITCH_DEG   = 30

-- Orientation control
local ORIENT_RESP       = 26
local ORIENT_TORQUE     = 2e8
local BANK2YAW_GAIN     = 0.25

-- Throttle ramping
local RAMP_UP_TIME      = 0.5
local RAMP_DOWN_TIME    = 0.3

-- Reset behavior
local RESET_KEEPS_PILOT = true
-- ===========================================================================

-- ---- Remotes / HUD state ----
local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"; remotes.Parent = ReplicatedStorage
local ResetPlane   = remotes:FindFirstChild("ResetPlane")   or Instance.new("RemoteEvent", remotes); ResetPlane.Name   = "ResetPlane"
local ControlState = remotes:FindFirstChild("ControlState") or Instance.new("RemoteEvent", remotes); ControlState.Name = "ControlState"
local SummonPlane  = remotes:FindFirstChild("SummonPlane")  or Instance.new("RemoteEvent", remotes); SummonPlane.Name  = "SummonPlane"

local PlaneState = ReplicatedStorage:FindFirstChild("PlaneState") or Instance.new("Folder")
PlaneState.Name = "PlaneState"; PlaneState.Parent = ReplicatedStorage
local PS_Speed  = PlaneState:FindFirstChild("Speed")    or Instance.new("NumberValue", PlaneState); PS_Speed.Name  = "Speed";  PS_Speed.Value  = 0
local PS_Fast   = PlaneState:FindFirstChild("FastMode") or Instance.new("BoolValue",   PlaneState); PS_Fast.Name   = "FastMode"; PS_Fast.Value = false
local PS_Seated = PlaneState:FindFirstChild("Seated")   or Instance.new("BoolValue",   PlaneState); PS_Seated.Name = "Seated"; PS_Seated.Value = false
local PS_Stall  = PlaneState:FindFirstChild("Stall")    or Instance.new("BoolValue",   PlaneState); PS_Stall.Name  = "Stall";  PS_Stall.Value  = false

-- ---- Single-plane state ----
local Plane, Body, Seat, Att, VF, AO, SpawnCF

local State = {
seatedPlr = nil,
desired = { yaw=0, pitch=0, roll=0, throttle=0, fast=false },
currentThrottle = 0,
targetThrottle  = 0,
}

-- ---- Utils ----
local function setAnchored(model, anchored)
for _, p in ipairs(model:GetDescendants()) do
if p:IsA("BasePart") then p.Anchored = anchored end
end
end

local function zero(model)
for _, p in ipairs(model:GetDescendants()) do
if p:IsA("BasePart") then
p.AssemblyLinearVelocity = Vector3.zero
p.AssemblyAngularVelocity = Vector3.zero
end
end
end

local function safeCFrameNearPlayer(plr: Player, fallbackCF: CFrame)
if not (plr and plr.Character and plr.Character.PrimaryPart) then return fallbackCF end
local cf = plr.Character.PrimaryPart.CFrame * CFrame.new(0, 6, -20)
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { plr.Character, Plane }
local size = Vector3.new(10, 3, 14)
for _ = 1, 8 do
if #workspace:GetPartBoundsInBox(cf, size, params) == 0 then break end
cf += Vector3.new(0, 2, 0)
end
return cf
end

local function softBrakeThenAnchor(duration)
duration = duration or 0.35
if not Plane or not Body then return end
local t0, startV = time(), Body.AssemblyLinearVelocity
local startF = VF and VF.Force or Vector3.zero
while time() - t0 < duration do
local a = (time() - t0) / duration
if VF then VF.Force = startF * (1 - a) end
Body.AssemblyLinearVelocity = startV * (1 - a)
RunService.Heartbeat:Wait()
end
if VF then VF.Force = Vector3.zero end
setAnchored(Plane, true)
end

-- ---- Core ----
local function spawnPlane(cf: CFrame)
if Plane then Plane:Destroy() end

Plane = Instance.new("Model"); Plane.Name = "PaperPlane"

Body = Instance.new("Part")
Body.Name = "Body"
Body.Size = Vector3.new(8, 0.5, 12)
Body.Material = Enum.Material.SmoothPlastic
Body.Color = Color3.fromRGB(245,245,245)
Body.Anchored = true
Body.Parent = Plane

Seat = Instance.new("Seat")
Seat.Name = "PilotSeat"
Seat.Disabled = true
Seat.Parent = Plane
local weld = Instance.new("WeldConstraint"); weld.Part0 = Body; weld.Part1 = Seat; weld.Parent = Body

Att = Instance.new("Attachment"); Att.Name = "RootAttach"; Att.Parent = Body

VF = Instance.new("VectorForce")
VF.Name = "Thrust"
VF.Attachment0 = Att
VF.RelativeTo = Enum.ActuatorRelativeTo.World
VF.ApplyAtCenterOfMass = true
VF.Force = Vector3.zero
VF.Parent = Body

AO = Instance.new("AlignOrientation")
AO.Name = "Attitude"
AO.Attachment0 = Att
AO.Mode = Enum.OrientationAlignmentMode.OneAttachment
AO.Responsiveness = ORIENT_RESP
AO.MaxTorque = ORIENT_TORQUE
AO.RigidityEnabled = false
AO.Parent = Body

Plane.PrimaryPart = Body
Plane:PivotTo(cf)
Plane.Parent = Workspace
SpawnCF = cf

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Ride"
prompt.ObjectText = "Paper Plane"
prompt.KeyboardKeyCode = Enum.KeyCode.R
prompt.HoldDuration = 0
prompt.RequiresLineOfSight = false
prompt.Parent = Seat

local function weldRider(char: Model)
if not USE_RIDER_WELD then return end
local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
local rw = Seat:FindFirstChild("RiderWeld"); if rw then rw:Destroy() end
local newWeld = Instance.new("WeldConstraint")
newWeld.Name = "RiderWeld"; newWeld.Part0 = hrp; newWeld.Part1 = Seat; newWeld.Parent = Seat
end

prompt.Triggered:Connect(function(plr)
if not plr or not plr.Character then return end
local hum = plr.Character:FindFirstChildOfClass("Humanoid"); if not hum then return end

task.spawn(function()
local deadline = time() + SIT_TIMEOUT_SEC
while Seat.Occupant ~= hum and time() < deadline do
Seat:Sit(hum) -- ✅ correct mount
task.wait(0.1)
end
end)

Seat.Disabled = false
weldRider(plr.Character)
pcall(function() Body:SetNetworkOwnership(nil) end)

zero(Plane); setAnchored(Plane, false)

State.seatedPlr = plr
State.desired = { yaw=0, pitch=0, roll=0, throttle=0, fast=true }
State.currentThrottle, State.targetThrottle = 0, 0
PS_Seated.Value = true; PS_Stall.Value = false
if prompt then prompt.Enabled = false end
end)

Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
if Seat.Occupant == nil then
local rw = Seat:FindFirstChild("RiderWeld"); if rw then rw:Destroy() end
State.seatedPlr = nil
VF.Force = Vector3.zero
AO.CFrame = CFrame.new()
setAnchored(Plane, true)
PS_Seated.Value, PS_Fast.Value, PS_Speed.Value, PS_Stall.Value = false, false, 0, false
local pr = Seat:FindFirstChildOfClass("ProximityPrompt"); if pr then pr.Enabled = true end
end
end)

-- Physics tick
local acc = 0
RunService.Heartbeat:Connect(function(dt)
acc += dt
local step = 1 / PHYS_HZ
while acc >= step do
acc -= step

if State.seatedPlr then
local d = State.desired
-- clamp inputs
local yaw   = math.clamp(d.yaw,   -1, 1) + math.clamp(d.roll, -1, 1) * BANK2YAW_GAIN
local pitch = math.clamp(d.pitch, -math.rad(80), math.rad(80))
local roll  = math.clamp(d.roll,  -math.rad(80), math.rad(80))

AO.CFrame = CFrame.fromEulerAnglesYXZ(pitch, yaw, roll)

-- Throttle ramp
local rampRate = (State.currentThrottle < State.targetThrottle) and (1 / RAMP_UP_TIME) or (1 / RAMP_DOWN_TIME)
State.currentThrottle = math.clamp(State.currentThrottle + rampRate * step, 0, 1)

local mass  = Body:GetMass()
local base  = (d.fast and THRUST_FAST or THRUST_SLOW)
local vel   = Body.AssemblyLinearVelocity
local speed = vel.Magnitude

-- Low-speed thrust boost
local slowFrac = math.clamp(1 - (speed / LOWSPEED_REF_V), 0, 1)
local boost    = 1 + LOWSPEED_THRUST * slowFrac

local damp     = math.max(0.2, 1 - (speed / MAX_SPEED))
local thrustN  = base * (mass/100) * State.currentThrottle * damp * boost
local fwd      = Body.CFrame.LookVector * thrustN

-- Correct AoA-based lift (positive when pitching up)
local aoa        = math.max(0, Body.CFrame.LookVector.Y)
local liftMag    = speed * LIFT_K * (1 + aoa * LIFT_PITCH_SCALAR)
local lift       = Body.CFrame.UpVector * liftMag

local drag = Vector3.zero
if speed > 0.1 then
drag = -vel.Unit * (speed * speed) * DRAG_K * mass
end

VF.Force = fwd + lift + drag

-- HUD
PS_Seated.Value = true
PS_Fast.Value   = d.fast
PS_Speed.Value  = math.floor(speed + 0.5)
local pitchDeg  = math.deg(math.asin(Body.CFrame.LookVector.Y))
PS_Stall.Value  = (speed < STALL_SPEED) and (pitchDeg > STALL_PITCH_DEG)
else
VF.Force = Vector3.zero
end
end
end)

-- Optional diagnostics
if DEV_DIAG then
local bb = Instance.new("BillboardGui")
bb.Name = "PlaneDiag"; bb.Size = UDim2.fromOffset(560, 64)
bb.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
bb.AlwaysOnTop = true; bb.Parent = Body
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1,1); tl.BackgroundTransparency = 0.2
tl.BackgroundColor3 = Color3.fromRGB(10,10,10)
tl.TextColor3 = Color3.new(1,1,1); tl.TextScaled = true
tl.Font = Enum.Font.SourceSansBold; tl.Text = "diag…"; tl.Parent = bb

RunService.Heartbeat:Connect(function()
local occ = (Seat.Occupant ~= nil) or (Seat:FindFirstChild("RiderWeld") ~= nil)
local v = Body.AssemblyLinearVelocity.Magnitude
tl.Text = string.format("Seated:%s v=%.1f fast=%s", tostring(occ), v, tostring(PS_Fast.Value))
end)
end
end

-- Reset / Summon / Controls
ResetPlane.OnServerEvent:Connect(function(plr)
if not Plane then return end
local pilot = Seat.Occupant and Players:GetPlayerFromCharacter(Seat.Occupant.Parent)
if pilot and pilot ~= plr then return end

softBrakeThenAnchor(0.35)
local dest = safeCFrameNearPlayer(plr, SpawnCF)
Plane:PivotTo(dest)

if RESET_KEEPS_PILOT and Seat.Occupant then
setAnchored(Plane, false)
PS_Seated.Value = true
else
Seat:Sit(nil)
local rw = Seat:FindFirstChild("RiderWeld"); if rw then rw:Destroy() end
local pr = Seat:FindFirstChildOfClass("ProximityPrompt"); if pr then pr.Enabled = true end
State.seatedPlr = nil
State.desired = { yaw=0, pitch=0, roll=0, throttle=0, fast=false }
State.currentThrottle, State.targetThrottle = 0, 0
PS_Seated.Value = false; PS_Fast.Value = false; PS_Speed.Value = 0; PS_Stall.Value = false
end
end)

SummonPlane.OnServerEvent:Connect(function(plr)
if not Plane then return end
softBrakeThenAnchor(0.25)
local near = safeCFrameNearPlayer(plr, SpawnCF)
Plane:PivotTo(near)
local pr = Seat:FindFirstChildOfClass("ProximityPrompt"); if pr then pr.Enabled = true end
State.seatedPlr = nil
end)

ControlState.OnServerEvent:Connect(function(plr, payload)
if plr ~= State.seatedPlr or not Plane or typeof(payload) ~= "table" then return end
local y,p,r,t,f = payload.yaw, payload.pitch, payload.roll, payload.throttle, payload.fast
if typeof(y)=="number" and typeof(p)=="number" and typeof(r)=="number" and typeof(t)=="number" and typeof(f)=="boolean" then
State.desired.yaw    = math.clamp(y, -1, 1)
State.desired.pitch  = math.clamp(p, -math.rad(80), math.rad(80))
State.desired.roll   = math.clamp(r, -math.rad(80), math.rad(80))
State.desired.fast   = f
State.targetThrottle = math.clamp(t, 0, 1)
end
end)

-- Initial spawn
local spawn = Workspace:FindFirstChildOfClass("SpawnLocation")
local cf = spawn and (spawn.CFrame * CFrame.new(0, 8, 0)) or CFrame.new(0, 12, 0)
spawnPlane(cf)

print('✅ [PaperPlaneSpawner] v1.3.6 "Golden Master+" — corrected AoA, fixed mount, ready to fly.')
