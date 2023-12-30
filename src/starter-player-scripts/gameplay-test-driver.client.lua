-- dependency
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

-- dependency
local GameplayTests = script.Parent:FindFirstChild("christmas-ornament-tests")
local CONFIG = require(script.Parent:FindFirstChild("christmas-config"))

-- init
local TestRunner = GameplayTestRunner({GameplayTests}, CONFIG)
