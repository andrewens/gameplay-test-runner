-- dependency
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Maid = require(script.Parent:FindFirstChild("Maid"))

local RemoteEvents = script.Parent:FindFirstChild("remote-events")
local InitializeGameplayTestRemote = RemoteEvents:FindFirstChild("InitializeGameplayTest")
local GetSessionIdRemote = RemoteEvents:FindFirstChild("GetSessionId")
local GetSessionTimestampRemote = RemoteEvents:FindFirstChild("GetSessionTimestamp")
local BrowseSessionTimestampsRemote = RemoteEvents:FindFirstChild("BrowseSessionTimestamps")
local SaveSessionRemote = RemoteEvents:FindFirstChild("SaveSession")

local TestSessionTimestampStore = DataStoreService:GetOrderedDataStore("TestSessionTimestamps")
--[[
	Session_SESSION_ID	--> int unix timestamp (when the test was saved last)
]]
local TestSessionStore = DataStoreService:GetGlobalDataStore("TestSessions")
--[[
	Session_SESSION_ID		/summary --> { int testIndex: { Passing: int, Failing: int, Total: int } }
							/logs --> { int testIndex: string }
							/score --> { Passing: int, Failing: int, Total: int }
]]

-- const
local MAX_SESSION_ID_DATASTORE_KEY = "MaxSessionId"
local SESSION_PAGE_IS_ASCENDING = false -- if false, newest tests get browsed first
local SESSION_PAGE_SIZE = 50
local SESSION_BROWSE_TIMEOUT = 2
local SESSION_SAVE_TIMEOUT = 20

-- var
local ServerMaid = Maid()
local sessionId -- unique integer index of this game/test session for use in database
local SessionTimestampsPage
local CachedPlayerNames = {} -- int userId --> string userName (cached from ROBLOX)
local LastSessionState -- cache test state to avoid unnecessary network calls
local lastSaveWasSuccessful

-- private | misc
local function disconnectRemoteFunction(RemoteFunction)
	--[[
		@param: Instance RemoteFunction
		@return: function that "disconnects" the RemoteFunction
			- it sets to an empty function to avoid yielding the client
				if for some reason the client still invokes these remotes
			- this method simplifies writing Maid tasks for disconnecting
				remote functions
	]]
	return function()
		RemoteFunction.OnServerInvoke = function() end
	end
end
local function getPlayerName(userId)
	--[[
		@param: int userId
		@return: string userName
		@post: yields, unless username is cached
	]]
	-- sanity check
	if not (typeof(userId) == "number" and math.floor(userId) == userId) then
		error(tostring(userId) .. " isn't an integer! It's a " .. typeof(userId))
	end

	-- return cached userName
	if CachedPlayerNames[userId] then
		return CachedPlayerNames[userId]
	end

	-- otherwise, look up the user name
	local s, playerName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if s then
		CachedPlayerNames[userId] = playerName
		return playerName
	end

	-- in case of network fail
	return "User_" .. tostring(userId)
end

-- private | session id shenanigans
local function sessionKey(anySessionId)
	--[[
		@return: string formattedSessionKey
			- Used for indexing database for a given session
		@param: int sessionId
	]]
	assert(typeof(anySessionId) == "number" and math.floor(anySessionId) == anySessionId)
	return "session_" .. tostring(anySessionId)
end
local function sessionKeyToId(anySessionKey)
	--[[
		@param: string anySessionKey
		@return: integer | nil anySessionId
			- convert a session key back to its integer session id
	]]
	local anySessionId = string.sub(anySessionKey, 9, -1)
	anySessionId = tonumber(anySessionId)
	return anySessionId
end
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

-- private | type checking & stuff
local function tableIsSubsetOf(a, b)
	--[[
		bool tableIsSubsetOf(a, b)

		Returns true if `a` is a subset of `b`.

		If both `a` and `b` are tables:
			- Returns true if all key/value pairs in `a` exist in `b`
			- Deep comparison -- checks at all levels recursively
		If neither `a` or `b` are tables:
			- Returns true if `a == b`
		Otherwise returns false
	]]

	if typeof(a) ~= typeof(b) then
		return false
	end
	if typeof(a) ~= "table" then
		return a == b
	end

	for keyA, valueA in a do
		local typeA = typeof(valueA)

		local valueB = b[keyA]
		local typeB = typeof(valueB)

		if typeA ~= typeB then
			return false
		end
		if typeA == "table" then
			return tableIsSubsetOf(valueA, valueB)
		elseif valueA ~= valueB then
			return false
		end
	end

	return true
end
local function deepTableEquality(t1, t2)
	return tableIsSubsetOf(t1, t2) and tableIsSubsetOf(t2, t1)
end
local function isInteger(any)
	return typeof(any) == "number" and any == math.floor(any)
end
local function isValidTestScore(TestScore)
	--[[
		@param: any TestScore
		@return: true if TestScore is a superset of this kind of table:
		{
			Passing: int
			Failing: int
			Total: int
		}
	]]

	if typeof(TestScore) ~= "table" then
		return false
	end

	return isInteger(TestScore.Passing) and isInteger(TestScore.Failing) and isInteger(TestScore.Total)
end

-- public? | network callbacks
local function getCurrentSessionId(Player)
	return sessionId
end
local function getSessionTimestamp(Player, anySessionId)
	return TestSessionTimestampStore:GetAsync(sessionKey(anySessionId))
end
local function browseSessionTimestamps(Player, startOver)
	--[[
		@param: Instance Player
		@param: bool | nil startOver
			- if true, then we make a new SessionTimestampsPage
		@return: array SessionData
				{ int i --> { int sessionId, int sessionTimestamp } }
	]]

	if startOver or SessionTimestampsPage == nil then
		SessionTimestampsPage = TestSessionTimestampStore:GetSortedAsync(SESSION_PAGE_IS_ASCENDING, SESSION_PAGE_SIZE)
	elseif not SessionTimestampsPage.IsFinished then
		SessionTimestampsPage:AdvanceToNextPageAsync()
	else
		return {}
	end

	local CurrentPage = SessionTimestampsPage:GetCurrentPage()
	local SessionData = {}
	local numLoadedSessions = 0
	local numTotalSessions = 0
	local startTime = os.clock()

	for i, Session in CurrentPage do
		-- we can get session id / timestamp from GetSortedAsync
		local thisSessionId = sessionKeyToId(Session.key)
		local thisSessionTimestamp = tonumber(Session.value)
		SessionData[i] = {
			thisSessionId,
			thisSessionTimestamp,
		}

		-- we have to use GetAsync to find the UserId's associated with the test
		numTotalSessions += 1
		task.spawn(function()
			local s, SessionSummary = pcall(TestSessionStore.GetAsync, TestSessionStore, Session.key .. "/score")
			if s and SessionSummary then
				SessionSummary = HttpService:JSONDecode(SessionSummary)
				local UserNames = {}
				for j, userId in SessionSummary.UserIds do
					UserNames[j] = getPlayerName(userId)
				end

				SessionData[i] = {
					thisSessionId,
					thisSessionTimestamp,

					UserNames,
					SessionSummary.Passing,
					SessionSummary.Failing,
					SessionSummary.Total,
				}
			end
			numLoadedSessions += 1
		end)
	end

	while numLoadedSessions < numTotalSessions or os.clock() - startTime > SESSION_BROWSE_TIMEOUT do
		task.wait()
	end

	return SessionData
end
local function saveThisSessionState(Player, SessionState)
	--[[
		@param: Instance Player
		@param: table SessionState {
			Passing: int
			Failing: int
			Total: int
			Summary: {
				int testIndex: { Passing: int, Failing: int, Total: int }
			},
			Logs: {
				int testIndex: string
			}
		}
		@post: SessionState is saved to database
		@post: SessionState is cached. If the state hasn't changed and the last save was successful,
			then it doesn't make any database calls
		@throw: if session id hasn't been initialized
	--]]

	-- sanity check
	if sessionId == nil then
		error(
			"gameplay-test-runner server hasn't been initialized.\nAttempt to save session before initializing session id."
		)
	end

	-- sanity check | parameters
	if typeof(SessionState) ~= "table" then
		error(tostring(SessionState) .. " isn't a table! It's a " .. typeof(SessionState))
	end
	if not isValidTestScore(SessionState) then
		error("SessionState is not a valid test score!")
	end
	if typeof(SessionState.Summary) ~= "table" then
		error(
			"SessionState.Summary = "
				.. tostring(SessionState.Summary)
				.. ", which isn't a table! It's a "
				.. typeof(SessionState.Summary)
		)
	end
	for testIndex, testScore in SessionState.Summary do
		if not isInteger(testIndex) then
			error(
				"SessionState.Summary["
					.. tostring(testIndex)
					.. "] is an invalid key; it's a "
					.. typeof(testIndex)
					.. " when it should be an integer"
			)
		end
		if not isValidTestScore(testScore) then
			error(
				"SessionState.Summary[" .. tostring(testIndex) .. "] isn't a valid test score: " .. tostring(testScore)
			)
		end
	end
	if typeof(SessionState.Logs) ~= "table" then
		error("SessionState.Logs = " .. tostring(SessionState.Logs) .. " which is a " .. typeof(SessionState.Logs) .. ", not a table")
	end
	for testIndex, testLog in SessionState.Logs do
		if typeof(testIndex) ~= "number" or math.floor(testIndex) ~= testIndex then
			error("The key at SessionState.Logs[" .. tostring(testIndex) .. "] isn't an integer! It's a " .. typeof(testIndex))
		end
		if typeof(testLog) ~= "string" then
			error("SessionState.Logs[" .. tostring(testIndex) .. "] isn't a string! It's a " .. typeof(testLog))
		end
	end

	-- don't do anything if SessionState hasn't changed and last save was successful
	if lastSaveWasSuccessful and deepTableEquality(SessionState, LastSessionState) then
		return true
	end
	lastSaveWasSuccessful = true

	-- data
	local numSuccessfulSaves = 0
	local numCompletedSaveAtttempts = 0
	local timestamp = os.time()
	local UserIds = { Player.UserId }
	local SessionScore = {
		Passing = SessionState.Passing,
		Failing = SessionState.Failing,
		Total = SessionState.Total,
		UserIds = UserIds,
	}

	-- save timestamp to an ordered datastore for browsing tests in chronological order
	task.spawn(function()
		local s, msg
		for tries = 1, 3 do
			s, msg =
				pcall(TestSessionTimestampStore.SetAsync, TestSessionTimestampStore, sessionKey(sessionId), timestamp)
			if s then
				break
			end
			task.wait(1)
		end
		numCompletedSaveAtttempts += 1
		if s then
			numSuccessfulSaves += 1
		else
			error("Failed to save test timestamp (session id: " .. tostring(sessionId) .. ")\n" .. tostring(msg))
		end
	end)

	-- save test score
	task.spawn(function()
		local s, msg
		for tries = 1, 3 do
			s, msg = pcall(
				TestSessionStore.SetAsync,
				TestSessionStore,
				sessionKey(sessionId) .. "/score",
				HttpService:JSONEncode(SessionScore),
				UserIds
			)
			if s then
				break
			end
			task.wait(1)
		end
		numCompletedSaveAtttempts += 1
		if s then
			numSuccessfulSaves += 1
		else
			error("Failed to save test score (session id: " .. tostring(sessionId) .. ")\n" .. tostring(msg))
		end
	end)

	-- save test summary
	task.spawn(function()
		local s, msg
		for tries = 1, 3 do
			s, msg = pcall(
				TestSessionStore.SetAsync,
				TestSessionStore,
				sessionKey(sessionId) .. "/summary",
				HttpService:JSONEncode(SessionState.Summary),
				UserIds
			)
			if s then
				break
			end
			task.wait(1)
		end
		numCompletedSaveAtttempts += 1
		if s then
			numSuccessfulSaves += 1
		else
			error("Failed to save test summary (session id: " .. tostring(sessionId) .. ")\n" .. tostring(msg))
		end
	end)

	-- save test logs
	task.spawn(function()
		local s, msg
		for tries = 1, 3 do
			s, msg = pcall(
				TestSessionStore.SetAsync,
				TestSessionStore,
				sessionKey(sessionId) .. "/logs",
				HttpService:JSONEncode(SessionState.Logs),
				UserIds
			)
			if s then
				break
			end
			task.wait(1)
		end
		numCompletedSaveAtttempts += 1
		if s then
			numSuccessfulSaves += 1
		else
			error("Failed to save test summary (session id: " .. tostring(sessionId) .. ")\n" .. tostring(msg))
		end
	end)

	-- yield until done saving
	while numCompletedSaveAtttempts < 4 or os.time() - timestamp > SESSION_SAVE_TIMEOUT do
		task.wait()
	end

	lastSaveWasSuccessful = numSuccessfulSaves >= numCompletedSaveAtttempts
	return lastSaveWasSuccessful
end

-- public
local function terminate()
	--[[
        @post: disconnects server from gameplay tests
        (you don't have to use this method -- initialize returns the same Maid)
    ]]
	ServerMaid:DoCleaning()
end
local function initialize(TestInitializers, UserIds)
	--[[
        @param: function(testName) | table TestInitializers
            { int i --> Instance (should contain module scripts returning functions) }
            { string testName --> function }
		@param: table UserIds -- users involved with this test
        @post: gameplay tests will invoke server functions
        @post: automatically terminates any previous initializations
		@post: assigns database session id if not already assigned
		@post: allows client to read database via RemoteFunctions
        @return: Maid
    ]]

	-- no double-initializing!
	terminate()

	-- sanity check
	if typeof(UserIds) ~= "table" then
		error(tostring(UserIds) .. " isn't a table! It's a " .. typeof(UserIds))
	end
	for i, userId in UserIds do
		if typeof(userId) ~= "number" or math.floor(userId) ~= userId then
			error("UserIds[" .. i .. "] = " .. tostring(userId) .. " isn't an integer. It's a " .. typeof(userId))
		end
	end

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
	ServerMaid(disconnectRemoteFunction(InitializeGameplayTestRemote))

	-- assign a unique id for this session for the database
	if sessionId == nil then
		local s, newSessionId
		for tries = 1, 3 do
			s, newSessionId =
				pcall(TestSessionStore.UpdateAsync, TestSessionStore, MAX_SESSION_ID_DATASTORE_KEY, getNewSessionId)
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

	-- allow client to read database
	GetSessionIdRemote.OnServerInvoke = getCurrentSessionId -- view this session's id
	GetSessionTimestampRemote.OnServerInvoke = getSessionTimestamp -- view timestamp of any session
	BrowseSessionTimestampsRemote.OnServerInvoke = browseSessionTimestamps -- view list of all sessions, ordered chronologically
	SaveSessionRemote.OnServerInvoke = saveThisSessionState -- save session state

	ServerMaid(disconnectRemoteFunction(GetSessionIdRemote))
	ServerMaid(disconnectRemoteFunction(GetSessionTimestampRemote))
	ServerMaid(disconnectRemoteFunction(BrowseSessionTimestampsRemote))
	ServerMaid(disconnectRemoteFunction(SaveSessionRemote))

	return ServerMaid
end

-- init
disconnectRemoteFunction(InitializeGameplayTestRemote)()
disconnectRemoteFunction(GetSessionIdRemote)()
disconnectRemoteFunction(GetSessionTimestampRemote)()
disconnectRemoteFunction(SaveSessionRemote)()
game:BindToClose(terminate)

return {
	initialize = initialize,
	terminate = terminate,
}
