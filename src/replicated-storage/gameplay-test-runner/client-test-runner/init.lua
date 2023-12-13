-- dependency
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Terminal = require(script:FindFirstChild("Terminal"))
local Maid = require(script.Parent:FindFirstChild("Maid"))

local RemoteEvents = script.Parent:FindFirstChild("remote-events")
local InitializeGameplayTestRemote = RemoteEvents:FindFirstChild("InitializeGameplayTest")
local GetSessionIdRemote = RemoteEvents:FindFirstChild("GetSessionId")
local GetSessionTimestampRemote = RemoteEvents:FindFirstChild("GetSessionTimestamp")

-- const
local DEFAULT_CONFIG = {
	PRIORITY_TESTS = {},
	ONLY_RUN_PRIORITY_TESTS = false,
	TEST_NAME_TO_SERVER_INITIALIZER = {},
}
local DEFAULT_COMMAND_LINE_PROMPT = LocalPlayer.Name .. ">"
local END_OF_TESTS_MESSAGE = "This is the last test!! <:{O"
local BEGINNING_OF_TESTS_MESSAGE = "You're already at the first test >:^("

local DEFAULT_TEXT_COLORS = {
	-- good colors
	jade = Color3.fromRGB(123, 245, 123),
	rust = Color3.fromRGB(255, 123, 123),
	seashell = Color3.fromRGB(200, 255, 255),
	pink = Color3.fromRGB(255, 200, 255),
	daffodil = Color3.fromRGB(255, 255, 150),
	white = Color3.new(1, 1, 1),

	-- simple colors
	green = Color3.new(0, 1, 0),
	blue = Color3.new(0, 0, 1),
	red = Color3.new(1, 0, 0),
	cyan = Color3.new(0, 1, 1),
	yellow = Color3.new(1, 1, 0),
	magenta = Color3.new(1, 0, 1),
	black = Color3.new(0.1, 0.1, 0.1),
	grey = Color3.new(0.5, 0.5, 0.5),
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

	-- public | test output commands
	local function logCommand(commandName)
		--[[
			@param: string commandName
			@post: saves user command to current test's output log
			(this is actually a private method but it's only for the TestCommands so...)
		]]
		local text = "\n" .. commandLineText .. commandName
		TestOutputs[testIndex] = (TestOutputs[testIndex] or "") .. text
	end
	local function redrawCurrentTest()
		--[[
			@post: clear screen & output current test's output log
		]]
		viewingSummary = false
		Console.clear()
		Console.output(TestOutputs[testIndex])
	end

	-- public | test navigation commands
	local function setTestIndex(_, newTestIndex)
		--[[
			@param: Console (unnecessary)
			@param: string newTestIndex
				- You can increment/decrement from command line by prepending a "+" or "-":
				- e.g. "+2", "-3", etc
			@post: updates testIndex, outputs current test log, resumes test thread
		]]

		-- turn newTestIndex into an actual integer representing a test
		if string.sub(newTestIndex, 1, 1) == "+" then
			-- support symbolic incrementing
			newTestIndex = testIndex + tonumber(string.sub(newTestIndex, 2, -1))
		elseif string.sub(newTestIndex, 1, 1) == "-" then
			-- support symbolic decrementing
			newTestIndex = testIndex - tonumber(string.sub(newTestIndex, 2, -1))
		else
			-- default rawsetting index behavior
			if tonumber(newTestIndex) == nil then
				error(tostring(newTestIndex) .. " isn't a number! It's a " .. typeof(newTestIndex))
			end
			newTestIndex = math.floor(tonumber(newTestIndex))
		end

		-- check bounds of newTestIndex (RETURNS)
		if newTestIndex > #GameplayTestOrder or newTestIndex < 1 then
			Console.output("\n\nThere is no Test #" .. tostring(newTestIndex) .. "\n")
			return
		end

		-- switch the test
		testIndex = newTestIndex
		redrawCurrentTest()

		-- ask server to initialize whatever it needs to for this test
		local clientTestName = GameplayTestOrder[testIndex] -- this nonsense VVV allows us to reuse a server function per multiple client tests
		local serverTestName = TEST_NAME_TO_SERVER_INITIALIZER[clientTestName] or clientTestName
		InitializeGameplayTestRemote:InvokeServer(serverTestName)

		-- resume test thread if it isn't finished
		if coroutine.status(TestThreads[testIndex]) == "dead" then
			TestConsole.setCommandLinePrompt()
			return
		end
		TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. GameplayTestOrder[testIndex] .. ">")
		if TestOutputs[testIndex] == nil then
			-- we only need to resume if the test thread hasn't been initialized yet
			coroutine.resume(TestThreads[testIndex])
		end
	end
	local function nextTest()
		--[[
			@post: moves onto next gameplay test (testIndex += 1)
		]]

		-- display cheeky message if we're at the end of the tests
		if testIndex >= #GameplayTestOrder then
			Console.output("\n\n" .. END_OF_TESTS_MESSAGE .. "\n")
			return
		end
		setTestIndex(nil, "+1")
	end
	local function prevTest()
		--[[
			@post: moves back to previous gameplay test (testIndex -= 1)
		]]
		-- display cheeky message if we're at the very beginning of the tests
		if testIndex <= 1 then
			Console.output("\n\n" .. BEGINNING_OF_TESTS_MESSAGE .. "\n")
			return
		end
		setTestIndex(nil, "-1")
	end

	-- public | response commands for "ask" prompts
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
			setTestIndex(nil, "+1") -- go onto next test
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
		nextStep(nil, true)
	end
	local function no()
		--[[
			@post: gives a "no" response to the last ask and resumes next step in current test
		]]
		nextStep(nil, false)
	end

	-- public | summary commands
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
			redrawCurrentTest()
		else
			prevTest()
		end
	end

	-- public | text coloring commands
	local function setTextColor(_, r, g, b)
		--[[
			@param: Console (we don't need it)
			@param: string color
		]]

		-- support picking color by name (RETURNS)
		if tonumber(r) == nil then
			Console.TextBox.TextColor3 = DEFAULT_TEXT_COLORS[r]
			return
		end

		-- support specifying a raw RGB value
		Console.TextBox.TextColor3 = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
	end
	local function viewTextColors(_)
		--[[
			@post: prints all default text colors to screen
		]]

		Console.output("\n\nDEFAULT TEXT COLORS\n")

		local longestColorName = 0 -- this is an int, sorry for bad naming convention
		for colorName, _ in DEFAULT_TEXT_COLORS do
			longestColorName = math.max(longestColorName, string.len(colorName))
		end

		for colorName, value in DEFAULT_TEXT_COLORS do
			Console.output(
				"\n "
					.. colorName
					.. string.rep(" ", longestColorName - string.len(colorName) + 2)
					.. math.floor(255 * value.R)
					.. " "
					.. math.floor(255 * value.G)
					.. " "
					.. math.floor(255 * value.B)
			)
		end
		Console.output(
			'\n\nType any color name to change the terminal text. For example, try "green" (without quotes).\n'
		)
	end

	-- public | database commands
	local function printSessionId()
		--[[
			@post: outputs the current session id to Console
		]]
		local sessionId = GetSessionIdRemote:InvokeServer()
		Console.output("\nYour current session id: " .. tostring(sessionId) .. "\n")
	end
	local function printSessionTimestamp(_, sessionId)
		--[[
			@param: Console (unnecessary)
			@param: int | string sessionId
				- if a string, should convert to an integer
		]]

		-- input sanitization
		sessionId = tonumber(sessionId)
		if sessionId == nil then
			error("Session id must be an integer!")
		end
		sessionId = math.floor(sessionId)

		-- ask the server
		local sessionTimestamp = GetSessionTimestampRemote:InvokeServer(sessionId)
		if sessionTimestamp then
			local LocalDateTime = DateTime.fromUnixTimestamp(sessionTimestamp)
			Console.output("\nSession #" .. tostring(sessionId) .. " ended on " .. LocalDateTime:FormatLocalTime("LLLL", "en-us"))
		else
			Console.output("\nSession #" .. tostring(sessionId) .. " doesn't exist")
		end
	end
	local function session(_, sessionId)
		--[[
			@param: Console (unnecessary)
			@param: int | string | nil sessionId
			@post: if sessionId is nil, prints the current session id of this game/test session
			@post: otherwise, prints the timestamp of the given session id
		]]
		if sessionId then
			printSessionTimestamp(_, sessionId)
			return
		end
		printSessionId()
	end
		

	-- public | encapsulate all commands
	local TestCommands = {
		-- redrawing the screen
		c = redrawCurrentTest,
		clear = redrawCurrentTest,
		redraw = redrawCurrentTest,

		-- navigating to specific tests
		test = setTestIndex,
		goto = setTestIndex,
		go = setTestIndex,
		number = setTestIndex,
		["#"] = setTestIndex,

		ne = nextTest,
		next = nextTest,
		skip = nextTest,

		p = prevTest,
		prev = prevTest,
		previous = prevTest,

		-- responses to "ask" questions
		yes = yes,
		y = yes,
		yeah = yes,
		ya = yes,
		yah = yes,
		yahh = yes,
		yep = yes,
		yesh = yes,
		yus = yes,
		yas = yes,
		affirmative = yes,
		mhm = yes,
		ye = yes,
		yuh = yes,
		yuhh = yes,
		yuhhh = yes,
		yuhhhh = yes,
		yuhhhhh = yes,
		yuhhhhhh = yes,

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

		-- navigating to/from summary
		back = back,
		b = back,

		summary = viewSummary,
		s = viewSummary,
		sum = viewSummary,
		sumsum = viewSummary,
		status = viewSummary,

		-- text colors
		setcolor = setTextColor,
		textcolor = setTextColor,
		text = setTextColor,
		color = setTextColor,

		palette = viewTextColors,
		colors = viewTextColors,

		-- database
		sessionid = printSessionId,
		id = printSessionId,

		sessiontime = printSessionTimestamp,
		timestamp = printSessionTimestamp,

		session = session,
	}
	for textColor, _ in DEFAULT_TEXT_COLORS do
		-- every default text color is a command
		-- beware of collisions!
		TestCommands[textColor] = function()
			setTextColor(nil, textColor)
		end
	end

	-- public | define Console wrapper for use in gameplay test code
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
		output = output, -- TODO consider renaming this to print since it includes automatic new lines, and for less confusion
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
			TestConsole.output("\nBEGIN TEST #" .. tostring(i) .. ' "' .. testName .. '"\n')
			TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. testName .. ">")
			testFunction(TestConsole)
			TestConsole.output(
				"\nFINISHED TEST #"
					.. tostring(i)
					.. ' "'
					.. testName
					.. '"\nPASSED '
					.. tostring(TestStatusPassing[i])
					.. " OUT OF "
					.. tostring(TestStatusPassing[i] + TestStatusFailing[i])
					.. " QUESTIONS\n"
					.. if i < #GameplayTestOrder then '\nType "next" (without quotes) to continue.\n' else ""
			)
			TestConsole.setCommandLinePrompt() -- defaults to PlayerName>

			if i >= #GameplayTestOrder then
				TestConsole.output("\nThis is the last gameplay test. Type \"summary\" (without quotes) to see your results.\n")
			end
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
