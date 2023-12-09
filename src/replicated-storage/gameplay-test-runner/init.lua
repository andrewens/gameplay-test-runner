-- dependency
local RunService = game:GetService("RunService")

-- init
local moduleName = if RunService:IsClient() then "client-test-runner" else "server-test-initializer"
return require(script:FindFirstChild(moduleName))
