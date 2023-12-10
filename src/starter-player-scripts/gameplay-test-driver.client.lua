-- dependency
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local GameplayTestsFolder = script.Parent:FindFirstChild("gameplay-tests")

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

-- private
local function test3(TestConsole)
	print("Hello world x3")
end

-- init
local CONFIG = {
    PRIORITY_TESTS = {
        "test1",
        "test2",
    },
    ONLY_RUN_PRIORITY_TESTS = false,
}
local GameplayTests = {
    test3 = test3,
    GameplayTestsFolder,
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer.PlayerGui

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(0, 400, 1, 0)
ScrollingFrame.Parent = ScreenGui

local TestRunner = GameplayTestRunner(ScrollingFrame, GameplayTests, CONFIG)

-- styling
ScrollingFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ScrollingFrame.BorderSizePixel = 0
TestRunner.TextBox.TextSize = 18
TestRunner.TextBox.TextColor3 = Color3.new(1, 1, 1)
TestRunner.TextBox.Font = Enum.Font.Code
TestRunner.TextBox.BackgroundTransparency = 1
