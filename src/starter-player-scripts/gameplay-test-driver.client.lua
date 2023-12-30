-- dependency
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

-- dependency
local GameplayTests = script.Parent:FindFirstChild("christmas-ornament-tests")
local CONFIG = require(script.Parent:FindFirstChild("christmas-config"))

-- init
local TestRunner = GameplayTestRunner({GameplayTests}, CONFIG)

-- styling
--[[
ScrollingFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ScrollingFrame.BorderSizePixel = 0
TestRunner.TextBox.TextSize = 18
TestRunner.TextBox.TextColor3 = Color3.new(1, 1, 1)
TestRunner.TextBox.Font = Enum.Font.Code
TestRunner.TextBox.BackgroundTransparency = 1--]]
