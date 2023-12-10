-- dependency
local Terminal = require(script:FindFirstChild("Terminal"))
local Maid = require(script:FindFirstChild("Maid"))

-- const
local DEFAULT_CONFIG = {
	PRIORITY_TESTS = {},
	ONLY_RUN_PRIORITY_TESTS = false,
	TEST_NAME_TO_SERVER_INITIALIZER = {},
}

-- public
return function(ScrollingFrame, GameplayTests, CONFIG)
	--[[
        @param: Instance ScrollingFrame
        @param: table GameplayTests
            { int i --> Instance (should have child module scripts) }
            { string testName --> function(TestConsole) }
        @param: nil | table Config {
            PRIORITY_TESTS:             nil | { int i --> string testName }
            ONLY_RUN_PRIORITY_TESTS:    nil | boolean
            TEST_NAME_TO_SERVER_INITIALIZER:   nil | { string testName --> string initializerName }
        }
        @return: Maid
    ]]

	-- sanity check
	if typeof(ScrollingFrame) ~= "Instance" then
		error(tostring(ScrollingFrame) .. " is not a ScrollingFrame! It's a " .. typeof(ScrollingFrame))
	end
	if not ScrollingFrame:IsA("ScrollingFrame") then
		error(tostring(ScrollingFrame) .. " is not a ScrollingFrame! It's a " .. ScrollingFrame.ClassName)
	end
	if typeof(GameplayTests) ~= "table" then
		error(tostring(GameplayTests) .. " is not a table! It's a " .. typeof(GameplayTests))
	end
	if CONFIG == nil then
		CONFIG = DEFAULT_CONFIG
	end
	if typeof(CONFIG) ~= "table" then
		error(tostring(CONFIG) .. " is not a table! It's a " .. typeof(CONFIG))
	end

	-- const
	local PRIORITY_TESTS = CONFIG.PRIORITY_TESTS or {}
	local ONLY_RUN_PRIORITY_TESTS = CONFIG.ONLY_RUN_PRIORITY_TESTS
	local TEST_NAME_TO_SERVER_INITIALIZER = CONFIG.TEST_NAME_TO_SERVER_INITIALIZER or {}

	-- var
	local GameplayTestOrder = {} -- int i --> string testName
	local GameplayTestFunctions = {} -- string testName --> function(TestConsole): nil
	local OrderedTests = {} -- string testName --> int i

	local TestRunnerMaid = Maid()
	local Console
	local TestConsole

	local testIndex = 1
	local TestThreads = {} -- int i --> thread of GameplayTestFunctions[i]

	-- private
	local function saveTestName(testName)
		--[[
            @post: assigns test to next spot in GameplayTestOrder
            @post: uses OrderedTests to avoid double-assigning the same test twice
        ]]

		-- sanity check
		if typeof(testName) ~= "string" then
			error("TestName " .. tostring(testName) .. " is not a string! It's a " .. typeof(testName))
		end

		-- init
		if OrderedTests[testName] then
			return
		end
		local i = #GameplayTestOrder + 1
		GameplayTestOrder[i] = testName
		OrderedTests[testName] = i
	end
	local function saveTestFunction(testName, testFunction)
		--[[
			@pre: all priority tests are already marked in OrderedTests
            @post: testFunction is saved to GameplayTestFunctions
            @post: testName is also saved
            @error: if testFunction was attempted to be defined twice
        ]]

		-- if we're only running priority tests, this prevents us
		-- from saving non-priority tests
		if ONLY_RUN_PRIORITY_TESTS and not OrderedTests[testName] then
			return
		end

		-- sanity check
		saveTestName(testName) -- this will error if testName isn't a string
		if typeof(testFunction) ~= "function" then
			error(
				'GameplayTests["'
					.. testName
					.. '"] = '
					.. tostring(testFunction)
					.. " is not a function! It's a "
					.. typeof(testFunction)
			)
		end
		if GameplayTestFunctions[testName] then
			error('GameplayTestFunction "' .. testName .. '" is already defined')
		end

		-- init
		GameplayTestFunctions[testName] = testFunction
	end
	local function saveTestInstances(ParentInstance)
		--[[
            @post: saves test functions from all ModuleScript descendants of ParentInstance
                    (including ParentInstance)
        ]]

		-- sanity check
		if typeof(ParentInstance) ~= "Instance" then
			error(tostring(ParentInstance) .. " is not an Instance! It's a " .. typeof(ParentInstance))
		end

		-- init
		local Descendants = ParentInstance:GetDescendants()
		table.insert(Descendants, ParentInstance)

		for _, ModuleScript in Descendants do
			if ModuleScript:IsA("ModuleScript") then
				saveTestFunction(ModuleScript.Name, require(ModuleScript))
			end
		end
	end
	local function extractGameplayTests()
		--[[
            @post: We know the order to run gameplay tests (GameplayTestOrder is populated)
            @post: We have all gameplay test functions (GameplayTestFunctions is populated)
            @error: if a priority test name has no gameplay test function defined for it
        ]]

		for _, testName in PRIORITY_TESTS do
			saveTestName(testName)
		end
		for key, value in GameplayTests do
			-- string testName --> function gameplayTest (CONTINUES)
			if typeof(key) == "string" then
				saveTestFunction(key, value)
				continue
			end

			-- int i --> Instance
			saveTestInstances(value)
		end
		for _, testName in PRIORITY_TESTS do
			if GameplayTestFunctions[testName] == nil then
				error('Priority test "' .. testName .. '" has no gameplay test function defined for it')
			end
		end
	end

	local function nextStep()
		-- don't do anything if we ran out of gameplay tests
		if testIndex > #GameplayTestOrder then
			Console.output("\n\nNo more gameplay tests!\n")
			return
		end

		-- move onto next test if current one is finished
		if coroutine.status(TestThreads[testIndex]) == "dead" then
			testIndex += 1
			Console.clear()

			-- don't do anything if we ran out of gameplay tests
			if testIndex > #GameplayTestOrder then
				Console.output("\n\nNo more gameplay tests!\n")
				return
			end
		end

		coroutine.resume(TestThreads[testIndex])
	end

	-- init
	extractGameplayTests()
	Console = Terminal(ScrollingFrame, {
		n = nextStep,
		next = nextStep,
	})
	TestRunnerMaid(Console)

	-- threads
	for i, testName in GameplayTestOrder do
		local testFunction = GameplayTestFunctions[testName]
		TestThreads[i] = coroutine.create(function()
			Console.clear()
			Console.output("\n" .. 'Begin test "' .. testName .. '"\n')
			testFunction(TestConsole)
			Console.output('\nEnd test "' .. testName .. '"\n')
		end)
	end

	--[[
        next -->
    ]]
	local function ask(prompt)
		Console.output("\n\n" .. prompt .. "\n")
		coroutine.yield()
	end
	local function output(text)
		return Console.output("\n" .. text)
	end
	TestConsole = {
		ask = ask,
		output = output,
	}
	setmetatable(TestConsole, { __index = Console })

	Console.initialize("next")

	return TestRunnerMaid
end
