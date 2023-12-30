-- dependency
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

--[[
-- dependency
local ServerTestInitializersFolder = script.Parent:FindFirstChild("server-test-initializers")

-- private
local function test2()
	print("Test initializer #2")
end

-- init
local ServerTestInitializers = {
	ServerTestInitializersFolder,
	test2 = test2,
}
local CONFIG = {
	ADMIN_USERS = {
		9792010, -- Rockraider400
		-1,
	}
}
Players.PlayerAdded:Connect(function(Player)
	GameplayTestRunner.initialize(ServerTestInitializers, CONFIG)
end)
--]]

-- dependency
local ServerTestInitializersFolder = script.Parent:FindFirstChild("christmas-ornament-tests")
local CONFIG = require(script.Parent:FindFirstChild("christmas-config"))

-- init
Players.PlayerAdded:Connect(function(Player)
	GameplayTestRunner.initialize({ ServerTestInitializersFolder }, CONFIG)
end)
