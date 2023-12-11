-- dependency
local Players = game:GetService("Players")
local Terminal = require(script:FindFirstChild("Terminal"))
local Maid = require(script:FindFirstChild("Maid"))

local LocalPlayer = Players.LocalPlayer

-- const
local DEFAULT_CONFIG = {
	PRIORITY_TESTS = {},
	ONLY_RUN_PRIORITY_TESTS = false,
	TEST_NAME_TO_SERVER_INITIALIZER = {},
}
local DEFAULT_COMMAND_LINE_PROMPT = LocalPlayer.Name .. ">"
local END_OF_TESTS_MESSAGE = "This is the last test!! <:{O"
local BEGINNING_OF_TESTS_MESSAGE = "You're already at the first test >:^("

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
	local TestConsole -- TestConsole wraps Console, allowing for convenience
	local commandLineText = DEFAULT_COMMAND_LINE_PROMPT

	local testIndex = 0
	local TestThreads = {} -- int i --> thread of GameplayTestFunctions[i]
	local TestOutputs = {} -- int i --> string outputLog (everything ever outputted during the test)
	local userResponse -- a yes/no answer to an "ask" question in a gameplay test

	local viewingSummary = false
	local TestStatusPassing = {} -- int i --> int number of "yes" responses per test
	local TestStatusFailing = {} -- int i --> int number of "no" responses per test

	-- private | compile gameplay tests from parameters
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

	-- public | define commands for CLI
	local function logCommand(commandName)
		--[[
			@param: string commandName
			@post: saves user command to current test's output log
			(this is actually a private method but it's only for the TestCommands so...)
		]]
		local text = "\n" .. commandLineText .. commandName
		TestOutputs[testIndex] = (TestOutputs[testIndex] or "") .. text
	end
	local function redrawCurrentTestOutput()
		--[[
			@post: clear screen & output current test's output log
		]]
		viewingSummary = false
		Console.clear()
		Console.output(TestOutputs[testIndex])
	end
	local function nextTest()
		--[[
			@post: moves onto next gameplay test (testIndex += 1)
		]]

		if testIndex >= #GameplayTestOrder then
			Console.output("\n\n" .. END_OF_TESTS_MESSAGE .. "\n")
			return
		end

		testIndex += 1
		redrawCurrentTestOutput()

		if coroutine.status(TestThreads[testIndex]) == "dead" then
			TestConsole.setCommandLinePrompt()
			return
		end
		TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. GameplayTestOrder[testIndex] .. ">")
		if TestOutputs[testIndex] == nil then
			coroutine.resume(TestThreads[testIndex])
		end
	end
	local function prevTest()
		--[[
			@post: moves back to previous gameplay test (testIndex -= 1)
		]]

		if testIndex <= 1 then
			Console.output("\n\n" .. BEGINNING_OF_TESTS_MESSAGE .. "\n")
			return
		end

		testIndex -= 1
		redrawCurrentTestOutput()

		if coroutine.status(TestThreads[testIndex]) == "dead" then
			TestConsole.setCommandLinePrompt()
			return
		end
		TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. GameplayTestOrder[testIndex] .. ">")
		if TestOutputs[testIndex] == nil then
			coroutine.resume(TestThreads[testIndex])
		end
	end
	local function nextStep(_, response)
		--[[
			@param: Console (this is how Terminal passes args to command functions -- we don't need it in this case.)
			@param: boolean | string response
			@post: runs current gameplay test until next "ask" prompt
			@post: if at end of current test, moves onto next test
		]]

		-- convert response to boolean in case of use by command line
		-- idk why i care about this tbh
		if typeof(response) ~= "boolean" then
			response = response == "yes"
		end

		-- don't do anything if viewing summary!
		if viewingSummary then
			if response then
				Console.output("\n\nYes to what exactly??\n")
			else
				Console.output("\n\nWhat are you talking about??\n")
			end
			return
		end

		-- don't do anything if we ran out of gameplay tests
		if testIndex > #GameplayTestOrder then
			Console.output("\n\n" .. END_OF_TESTS_MESSAGE .. "\n")
			return
		end

		-- move onto next test if current one is finished
		if coroutine.status(TestThreads[testIndex]) == "dead" then
			nextTest()
			return
		end

		-- actually run the next step of the test
		userResponse = response
		logCommand(if response then "yes" else "no")

		TestConsole.output()
		coroutine.resume(TestThreads[testIndex])
	end
	local function yes()
		--[[
			@post: gives a "yes" response to the last ask and resumes next step in current test
		]]
		nextStep(TestConsole, true)
	end
	local function no()
		--[[
			@post: gives a "no" response to the last ask and resumes next step in current test
		]]
		nextStep(TestConsole, false)
	end
	local function viewSummary()
		--[[
			@post: draws summary of all test status (passing/failing) to screen
		]]
		viewingSummary = true
		Console.clear()
		TestConsole.setCommandLinePrompt()

		-- summarize test status
		local TestStatus = {}
		local numPassingTests = 0

		for i, testName in GameplayTestOrder do
			if coroutine.status(TestThreads[i]) == "dead" then
				local n = TestStatusPassing[i] + TestStatusFailing[i]
				TestStatus[i] = " ("
					.. tostring(TestStatusPassing[i])
					.. "/"
					.. tostring(n)
					.. ") "
					.. if TestStatusFailing[i] > 0 then "[FAILING]" else "[PASSING]"

				if TestStatusFailing[i] <= 0 then
					numPassingTests += 1
				end
			elseif TestStatusPassing[i] > 0 or TestStatusFailing[i] > 0 then
				TestStatus[i] = " (IN-PROGRESS)"
			end

			if testIndex == i then
				TestStatus[i] = (TestStatus[i] or "") .. " <-- current"
			end
		end

		-- draw summary to screen
		Console.output("\nTEST SUMMARY\n")
		Console.output(
			"\n" .. tostring(numPassingTests) .. " PASSING OUT OF " .. tostring(#GameplayTestOrder) .. " TESTS\n"
		)
		for i, testName in GameplayTestOrder do
			Console.output("\n#" .. tostring(i) .. " " .. testName .. (TestStatus[i] or ""))
		end
		Console.output('\n\nType "back" (without quotes) to continue.\n')
	end
	local function back()
		--[[
			@post: if viewing summary, simply exits summary.
			@post: otherwise, goes to previous test
		]]
		if viewingSummary then
			-- exit summary view
			redrawCurrentTestOutput()
		else
			prevTest()
		end
	end
	local TestCommands = {
		yes = yes,
		y = yes,
		yeah = yes,
		ya = yes,
		yep = yes,
		yesh = yes,
		yus = yes,
		yas = yes,
		affirmative = yes,
		mhm = yes,
		ye = yes,

		no = no,
		n = no,
		nah = no,
		nope = no,
		negative = no,
		idk = no,
		noe = no,
		nop = no,

		nextstep = nextStep,
		step = nextStep,
		ok = nextStep,

		ne = nextTest,
		next = nextTest,
		skip = nextTest,

		p = prevTest,
		prev = prevTest,
		previous = prevTest,

		back = back,
		b = back,

		summary = viewSummary,
		s = viewSummary,
		sum = viewSummary,
		sumsum = viewSummary,
		status = viewSummary,

		clear = redrawCurrentTestOutput,
		redraw = redrawCurrentTestOutput,
	}

	-- wrap Console for giving to gameplay test functions as "TestConsole"
	local function output(text)
		--[[
			@param: string text
			@post: outputs to Console
			@post: saves text to the test's output log (TestOutputs[testIndex])
		]]
		text = "\n" .. (text or "")
		TestOutputs[testIndex] = (TestOutputs[testIndex] or "") .. text
		return Console.output(text)
	end
	local function ask(prompt)
		--[[
			@param: string prompt
			@return: bool userResponse (i.e. the user says yes or they say no)
		]]
		userResponse = nil
		output(prompt .. "\n")
		coroutine.yield()

		if userResponse then
			TestStatusPassing[testIndex] += 1
		else
			TestStatusFailing[testIndex] += 1
		end
		return userResponse
	end
	local function setCommandLinePrompt(text)
		--[[
			@param: string text
			@post: saves commandLineText for when we save user commands to the test log
		]]
		commandLineText = text or DEFAULT_COMMAND_LINE_PROMPT
		Console.setCommandLinePrompt(commandLineText)
	end
	TestConsole = {
		ask = ask,
		output = output,
		setCommandLinePrompt = setCommandLinePrompt,
	}

	-- init
	extractGameplayTests()
	Console = Terminal(ScrollingFrame, TestCommands)
	TestRunnerMaid(Console)
	setmetatable(TestConsole, { __index = Console })

	-- create a thread per test function
	for i, testName in GameplayTestOrder do
		-- init question summary
		TestStatusPassing[i] = 0
		TestStatusFailing[i] = 0

		-- init test fn. thread
		local testFunction = GameplayTestFunctions[testName]
		TestThreads[i] = coroutine.create(function()
			TestConsole.clear()
			TestConsole.output("\nBEGIN TEST #" .. tostring(i) .. ', "' .. testName .. '"\n')
			TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. testName .. ">")
			testFunction(TestConsole)
			TestConsole.output(
				"\nFINISHED TEST #"
					.. tostring(i)
					.. ', "'
					.. testName
					.. '"\nPASSED '
					.. tostring(TestStatusPassing[i])
					.. " OUT OF "
					.. tostring(TestStatusPassing[i] + TestStatusFailing[i])
					.. " QUESTIONS\n"
					.. if i < #GameplayTestOrder then '\nType "next" (without quotes) to continue.\n' else ""
			)
			TestConsole.setCommandLinePrompt() -- defaults to PlayerName>
		end)
	end

	-- automatically begin running tests
	nextTest()
	Console.initialize()

	-- this object exposes Terminal's TextBox and
	-- allows you to destroy the whole thing
	-- with :Destroy() or :destroy()
	return setmetatable({
		TextBox = Console.TextBox,
	}, {
		__index = TestRunnerMaid,
	})
end
