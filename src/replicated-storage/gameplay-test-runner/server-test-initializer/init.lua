-- dependency
local DataStoreService = game:GetService("DataStoreService")

local Maid = require(script.Parent:FindFirstChild("Maid"))

local RemoteEvents = script.Parent:FindFirstChild("remote-events")
local InitializeGameplayTestRemote = RemoteEvents:FindFirstChild("InitializeGameplayTest")
local GetSessionIdRemote = RemoteEvents:FindFirstChild("GetSessionId")

local TestSessionTimestampsStore = DataStoreService:GetOrderedDataStore("TestSessionTimestamps")
local TestSessionStore = DataStoreService:GetGlobalDataStore("TestSessions")

-- const
local MAX_SESSION_ID_DATASTORE_KEY = "MaxSessionId"

-- var
local ServerMaid = Maid()
local sessionId -- unique integer index of this game/test session for use in database

--[[
	0. assign session id
	1. know what session id is
	2. save timestamp with session id
	3. include user id as metadata
	4. browse all test timestamps
]]

-- private
local function getNewSessionId(maxSessionId)
	--[[
		Callback for TestSessionStore:UpdateAsync(MAX_SESSION_ID_DATASTORE_KEY, ...)
		Increments max session id so we can get a unique id for this player's session
		@param: int maxSessionId | nil
		@return: maxSessionId + 1 | 1
	]]
	if maxSessionId then
		return maxSessionId + 1
	end
	return 1
end

-- public
local function terminate()
	--[[
        @post: disconnects server from gameplay tests
        (you don't have to use this method -- initialize returns the same Maid)
    ]]
	ServerMaid:DoCleaning()
end
local function initialize(TestInitializers)
	--[[
        @param: function(testName) | table TestInitializers
            { int i --> Instance (should contain module scripts returning functions) }
            { string testName --> function }
        @post: gameplay tests will invoke server functions
        @post: automatically terminates any previous initializations
		@post: assigns database session id if not already assigned
        @return: Maid
    ]]

	-- no double-initializing!
	terminate()

	-- set up gameplay test initializer function(s)
	if typeof(TestInitializers) == "function" then
		InitializeGameplayTestRemote.OnServerInvoke = function(Player, ...)
			return TestInitializers(...)
		end
	elseif typeof(TestInitializers) == "table" then
		-- var
		local TestInitializerFunctions = {} -- string testName --> function(testName): nil

		-- private
		local function saveTestInitializer(testName, initFunction)
			--[[
                @param: string testName
                @param: function initFunction
                @post: save the test initializer function to TestInitializerFunctions
            ]]
			if typeof(initFunction) ~= "function" then
				error(tostring(initFunction) .. " isn't a function! It's a " .. typeof(initFunction))
			end
			if TestInitializerFunctions[testName] then
				error('Attempt to define server test initializer "' .. tostring(testName) .. '" more than once')
			end
			TestInitializerFunctions[testName] = initFunction
		end
		local function initGameplayTest(testName)
			--[[
                @param: string testName
                @post: runs test function with given test name
                @error: if no test initializer defined for the given test name
            ]]
			local initTest = TestInitializerFunctions[testName]
			if initTest == nil then
				error("There's no server test initializer named \"" .. tostring(testName) .. '"')
			end
			return initTest(testName)
		end

		-- init
		for key, value in TestInitializers do
			-- string testName --> function
			if typeof(key) == "string" then
				saveTestInitializer(key, value)
				continue
			end

			-- int i --> Instance
			if typeof(value) ~= "Instance" then
				error(tostring(value) .. " isn't an Instance! It's a " .. typeof(value))
			end
			local Descendants = value:GetDescendants()
			table.insert(Descendants, value)
			for _, ModuleScript in Descendants do
				if ModuleScript:IsA("ModuleScript") then
					saveTestInitializer(ModuleScript.Name, require(ModuleScript))
				end
			end
		end
		InitializeGameplayTestRemote.OnServerInvoke = function(Player, ...)
			return initGameplayTest(...)
		end
	else
		-- sanity check
		error(tostring(TestInitializers) .. " is not a table or function! It's a " .. typeof(TestInitializers))
	end
	ServerMaid(function()
		InitializeGameplayTestRemote.OnServerInvoke = function() end -- avoid yielding on client
	end)

	-- assign a unique id for this session for the database
	if sessionId == nil then
		local s, newSessionId
		for tries = 1, 3 do
			s, newSessionId = pcall(TestSessionStore.UpdateAsync, TestSessionStore, MAX_SESSION_ID_DATASTORE_KEY, getNewSessionId)
			if s then
				sessionId = newSessionId
				break
			end
			task.wait(1)
		end
		if not s then
			terminate()
			error("Failed to get new session id\n" .. newSessionId)
		end
	end
	GetSessionIdRemote.OnServerInvoke = function(...)
		return sessionId
	end
	ServerMaid(function()
		GetSessionIdRemote.OnServerInvoke = function() end -- avoid yielding on client
	end)

	return ServerMaid
end

-- init
InitializeGameplayTestRemote.OnServerInvoke = function() end -- avoid yielding on client
GetSessionIdRemote.OnServerInvoke = function() end
game:BindToClose(terminate)

return {
	initialize = initialize,
	terminate = terminate,
}
