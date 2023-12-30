-- dependency
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

--[[
-- dependency
local GameplayTestsFolder = script.Parent:FindFirstChild("gameplay-tests")

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
    TEST_NAME_TO_SERVER_INITIALIZER = {
        ["test3"] = "test2", -- this means that test3 reuses the same server code as test2
    }
}
local GameplayTests = {
    test3 = test3,
    GameplayTestsFolder,
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer.PlayerGui

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(0, 600, 1, 0)
ScrollingFrame.Parent = ScreenGui

local TestRunner = GameplayTestRunner(ScrollingFrame, GameplayTests, CONFIG)

-- styling
ScrollingFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ScrollingFrame.BorderSizePixel = 0
TestRunner.TextBox.TextSize = 18
TestRunner.TextBox.TextColor3 = Color3.new(1, 1, 1)
TestRunner.TextBox.Font = Enum.Font.Code
TestRunner.TextBox.BackgroundTransparency = 1
--]]

-- dependency
local GameplayTests = script.Parent:FindFirstChild("christmas-ornament-tests")
local CONFIG = require(script.Parent:FindFirstChild("christmas-config"))

-- init
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = LocalPlayer.PlayerGui

local ScrollingFrame = Instance.new("ScrollingFrame")
ScrollingFrame.Size = UDim2.new(0, 400, 1, 0)
ScrollingFrame.Parent = ScreenGui

local TestRunner = GameplayTestRunner(ScrollingFrame, {GameplayTests}, CONFIG)

-- styling
ScrollingFrame.BackgroundColor3 = Color3.new(0, 0, 0)
ScrollingFrame.BorderSizePixel = 0
TestRunner.TextBox.TextSize = 18
TestRunner.TextBox.TextColor3 = Color3.new(1, 1, 1)
TestRunner.TextBox.Font = Enum.Font.Code
TestRunner.TextBox.BackgroundTransparency = 1
