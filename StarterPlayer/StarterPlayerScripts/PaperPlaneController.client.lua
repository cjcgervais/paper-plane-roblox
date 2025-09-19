-- PaperPlaneController.client.lua (v1.3.3 — Seat-aware input; no W hijack on foot)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Remotes / HUD
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ControlState = Remotes:WaitForChild("ControlState")
local ResetPlane   = Remotes:WaitForChild("ResetPlane")
local SummonPlane  = Remotes:WaitForChild("SummonPlane")

local PlaneState = ReplicatedStorage:WaitForChild("PlaneState")
local PS_Seated  = PlaneState:WaitForChild("Seated")

-- === Config ===
local INVERT_PITCH    = false
local SWAP_YAW_ROLL   = false
local ENABLE_MOUSE    = true
local MOUSE_YAW_GAIN  = 1.2
local MOUSE_PITCH_GAIN= 1.0
local KEY_AXIS_GAIN   = 1.0
local AXIS_RATE       = 6.0
local DEADZONE        = 0.05
local SEND_HZ         = 30
local RAMP_UP, RAMP_DOWN = 0.5, 0.3

-- Input state
local input = { yaw=0, pitch=0, roll=0, throttle=0, fast=false }
local yawTarget, pitchTarget, rollTarget = 0, 0, 0
local currentThrottle, targetThrottle = 0, 0

-- Controls priority
local PRIORITY = Enum.ContextActionPriority.High.Value + 20
local sendAcc, SEND_STEP = 0, 1 / SEND_HZ

-- Disable default character controls only while seated
local controls
do
local pm = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")
controls = require(pm):GetControls()
end

local function seated() return PS_Seated.Value == true end

local function setSeatedMovementDisabled(disabled: boolean)
if not controls then return end
if disabled then controls:Disable() else controls:Enable() end
end

-- Helpers
local function axisClamp(v) if math.abs(v) < DEADZONE then return 0 end; return math.clamp(v, -1, 1) end
local function applyConfig(yawK, pitchK, rollK)
return axisClamp(yawK * KEY_AXIS_GAIN),
       axisClamp(pitchK * KEY_AXIS_GAIN * (INVERT_PITCH and -1 or 1)),
       axisClamp(rollK * KEY_AXIS_GAIN)
end

-- Key map
local k = {A=false,D=false,Q=false,E=false,Space=false,LShift=false,W=false,LControl=false}

local function recomputeKeyTargets()
local yawK,pitchK,rollK = 0,0,0
if not SWAP_YAW_ROLL then
if k.A then yawK -= 1 end; if k.D then yawK += 1 end
if k.Q then rollK -= 1 end; if k.E then rollK += 1 end
else
if k.A then rollK -= 1 end; if k.D then rollK += 1 end
if k.Q then yawK -= 1 end; if k.E then yawK += 1 end
end
if k.Space  then pitchK += 1 end
if k.LShift then pitchK -= 1 end
yawTarget, pitchTarget, rollTarget = applyConfig(yawK, pitchK, rollK)
end

local function setKey(sym, isDown)
if k[sym] == nil then return end
k[sym] = isDown
if sym == "LControl" and isDown and seated() then
input.fast = not input.fast
end
if sym == "W" then targetThrottle = isDown and 1 or 0 end
recomputeKeyTargets()
end

-- Seat-gated binding result
local function seatAwareResult()
return seated() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
end

local function actionHandler(_, state, obj)
local result = seatAwareResult()
local allowPlaneActions = seated()

if state == Enum.UserInputState.Begin then
local kc = obj.KeyCode
if kc == Enum.KeyCode.A then setKey("A", true)
elseif kc == Enum.KeyCode.D then setKey("D", true)
elseif kc == Enum.KeyCode.Q then setKey("Q", true)
elseif kc == Enum.KeyCode.E then setKey("E", true)
elseif kc == Enum.KeyCode.Space then setKey("Space", true)
elseif kc == Enum.KeyCode.LeftShift then setKey("LShift", true)
elseif kc == Enum.KeyCode.W then setKey("W", true)
elseif kc == Enum.KeyCode.LeftControl and allowPlaneActions then setKey("LControl", true)
elseif kc == Enum.KeyCode.F and allowPlaneActions then ResetPlane:FireServer()
elseif kc == Enum.KeyCode.G and allowPlaneActions then SummonPlane:FireServer()
end
elseif state == Enum.UserInputState.End then
local kc = obj.KeyCode
if kc == Enum.KeyCode.A then setKey("A", false)
elseif kc == Enum.KeyCode.D then setKey("D", false)
elseif kc == Enum.KeyCode.Q then setKey("Q", false)
elseif kc == Enum.KeyCode.E then setKey("E", false)
elseif kc == Enum.KeyCode.Space then setKey("Space", false)
elseif kc == Enum.KeyCode.LeftShift then setKey("LShift", false)
elseif kc == Enum.KeyCode.W then setKey("W", false)
elseif kc == Enum.KeyCode.LeftControl and allowPlaneActions then setKey("LControl", false)
end
end

return result
end

local binds = {{"PP_A", actionHandler, Enum.KeyCode.A},
{"PP_D", actionHandler, Enum.KeyCode.D},
{"PP_Q", actionHandler, Enum.KeyCode.Q},
{"PP_E", actionHandler, Enum.KeyCode.E},
{"PP_Space", actionHandler, Enum.KeyCode.Space},
{"PP_Shift", actionHandler, Enum.KeyCode.LeftShift},
{"PP_W", actionHandler, Enum.KeyCode.W},
{"PP_LCtl", actionHandler, Enum.KeyCode.LeftControl},
{"PP_Reset", actionHandler, Enum.KeyCode.F},
{"PP_Summon", actionHandler, Enum.KeyCode.G},
}
for _, b in ipairs(binds) do
CAS:BindActionAtPriority(b[1], b[2], false, PRIORITY, b[3])
end

-- Seat change → enable/disable character controls and clear inputs
local function refreshSeated()
local s = seated()
setSeatedMovementDisabled(s)
if not s then
k = {A=false,D=false,Q=false,E=false,Space=false,LShift=false,W=false,LControl=false}
yawTarget, pitchTarget, rollTarget = 0,0,0
currentThrottle, targetThrottle = 0,0
input = { yaw=0, pitch=0, roll=0, throttle=0, fast=false }
end
end
PS_Seated:GetPropertyChangedSignal("Value"):Connect(refreshSeated)
refreshSeated()

-- Main loop
RunService.RenderStepped:Connect(function(dt)
local lerp = math.clamp(AXIS_RATE * dt, 0, 1)
input.yaw   += (yawTarget   - input.yaw)   * lerp
input.pitch += (pitchTarget - input.pitch) * lerp
input.roll  += (rollTarget  - input.roll)  * lerp

if PS_Seated.Value and ENABLE_MOUSE and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
local dx, dy = UIS:GetMouseDelta().X, UIS:GetMouseDelta().Y
input.yaw   = axisClamp(input.yaw   + (dx/300) * MOUSE_YAW_GAIN)
input.pitch = axisClamp(input.pitch + (-dy/300) * MOUSE_PITCH_GAIN)
end

local rate = (currentThrottle < targetThrottle) and (1/RAMP_UP) or (1/RAMP_DOWN)
currentThrottle = math.clamp(currentThrottle + rate * dt, 0, 1)
input.throttle = currentThrottle

sendAcc += dt
if sendAcc >= SEND_STEP and PS_Seated.Value then
sendAcc -= SEND_STEP
ControlState:FireServer({
yaw = input.yaw,
pitch = input.pitch,
roll = input.roll,
throttle = input.throttle,
fast = input.fast,
})
end
end)
