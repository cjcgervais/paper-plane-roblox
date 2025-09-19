-- PaperPlaneHUD.client.lua (v1.1)
-- Minimal HUD showing speed, fast mode, and stall warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlaneState = ReplicatedStorage:WaitForChild("PlaneState")
local PS_Speed  = PlaneState:WaitForChild("Speed")
local PS_Fast   = PlaneState:WaitForChild("FastMode")
local PS_Seated = PlaneState:WaitForChild("Seated")
local PS_Stall  = PlaneState:WaitForChild("Stall")

local player = Players.LocalPlayer
local pgui = player:WaitForChild("PlayerGui")

-- Build UI
local gui = Instance.new("ScreenGui")
gui.Name = "PaperPlaneHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = pgui

local function mkLabel(name, anchor, pos, size, color, text)
local t = Instance.new("TextLabel")
t.Name = name
t.AnchorPoint = anchor
t.Position = pos
t.Size = size
t.BackgroundTransparency = 0.35
t.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
t.TextColor3 = color or Color3.new(1,1,1)
t.Font = Enum.Font.SourceSansBold
t.TextScaled = true
t.Text = text or ""
t.Parent = gui
return t
end

local speedLabel = mkLabel(
"Speed",
Vector2.new(0,1),
UDim2.fromScale(0.02, 0.98),
UDim2.fromScale(0.16, 0.08),
Color3.new(1,1,1),
"SPEED 0"
)

local modeLabel = mkLabel(
"Mode",
Vector2.new(0.5,1),
UDim2.fromScale(0.5, 0.98),
UDim2.fromScale(0.2, 0.06),
Color3.fromRGB(180, 230, 255),
"MODE: SLOW"
)

local stallLabel = mkLabel(
"Stall",
Vector2.new(1,1),
UDim2.fromScale(0.98, 0.98),
UDim2.fromScale(0.16, 0.08),
Color3.fromRGB(255, 220, 220),
"STALL!"
)
stallLabel.Visible = false

-- Seat helper overlay (optional)
local help = mkLabel(
"Help",
Vector2.new(0.5,0),
UDim2.fromScale(0.5, 0.02),
UDim2.fromScale(0.5, 0.06),
Color3.fromRGB(220, 255, 220),
"R=Ride  |  W=Throttle  |  Space/Shift=Pitch  |  Q/E=Roll  |  A/D=Yaw  |  LCtrl=Fast  |  F=Reset  |  G=Summon"
)
help.BackgroundTransparency = 0.5

local function refresh()
speedLabel.Text = ("SPEED %d"):format(PS_Speed.Value)
modeLabel.Text  = PS_Fast.Value and "MODE: FAST" or "MODE: SLOW"
stallLabel.Visible = PS_Stall.Value and PS_Seated.Value
help.Visible = not PS_Seated.Value
end

PS_Speed:GetPropertyChangedSignal("Value"):Connect(refresh)
PS_Fast:GetPropertyChangedSignal("Value"):Connect(refresh)
PS_Stall:GetPropertyChangedSignal("Value"):Connect(refresh)
PS_Seated:GetPropertyChangedSignal("Value"):Connect(refresh)
refresh()
