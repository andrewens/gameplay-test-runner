-- dependency
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerTestInitializersFolder = script.Parent:FindFirstChild("server-test-initializers")

local GameplayTestRunner = require(ReplicatedStorage:FindFirstChild("gameplay-test-runner"))

-- private
local function test2()
	print("Hello world x2")
end

-- init
local ServerTestInitializers = {
    ServerTestInitializersFolder,
    test2 = test2
}
local ServerTests = GameplayTestRunner(ServerTestInitializers)
