-- dependency
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

local Terminal = require(script:FindFirstChild("Terminal"))
local Maid = require(script.Parent:FindFirstChild("Maid"))

local RemoteEvents = script.Parent:FindFirstChild("remote-events")
local InitializeGameplayTestRemote = RemoteEvents:FindFirstChild("InitializeGameplayTest")
local GetSessionIdRemote = RemoteEvents:FindFirstChild("GetSessionId")
local GetSessionTimestampRemote = RemoteEvents:FindFirstChild("GetSessionTimestamp")
local BrowseSessionTimestampsRemote = RemoteEvents:FindFirstChild("BrowseSessionTimestamps")
local SaveSessionRemote = RemoteEvents:FindFirstChild("SaveSession")
local GetSessionSummaryRemote = RemoteEvents:FindFirstChild("GetSessionSummary")
local GetTestLogRemote = RemoteEvents:FindFirstChild("GetTestLog")
local EraseSessionRemote = RemoteEvents:FindFirstChild("EraseSession")

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
local MAX_SESSION_ID_STRING_LENGTH = 4 -- max number of expected digits for a session id, for formatting reasons
local AUTO_SAVE_RATE = 5 -- seconds between auto-saves
local LOCAL_PLAYER_NAME = LocalPlayer.Name
local COMMAND_METADATA = {} -- string commandName | alias --> CommandMetadata
local HORIZONTAL_LINE_WIDTH = 62 -- length of "======" strings
local NUM_HELP_COLUMNS = 4
local HELP_COLUMN_WIDTH = math.floor(HORIZONTAL_LINE_WIDTH / NUM_HELP_COLUMNS)
local DEFAULT_RAINBOW_PERIOD = 20
local DEFAULT_RAINBOW_STEPS = 12
local CANONICAL_COMMAND_METADATA = { -- string commandName --> { <metadata> }
	--[[
		string commandName --> {
			Description: nil | string desc,
			Aliases: nil | { string alternateCommandName },
				--> always put the "official"/canonical command name first
			Arguments: nil | { string argumentName: { string typeName } },
			Usage: nil | { string exampleUsage }
		}
	]]

	-- universal commands
	help = {
		Description = "Lists all commands. If `commandName` is specified, prints documentation for that command.",
		Aliases = { "help", "h" },
		Arguments = {
			{
				Name = "commandName",
				Types = { "string", "nil" },
			},
		},
		Usage = {
			"-- list all commands\n" .. LOCAL_PLAYER_NAME .. ">help",
			"-- list help for a specific command\n-- (in this case, the 'next' command)\n"
				.. LOCAL_PLAYER_NAME
				.. ">help next",
		},
	},
	clear = {
		Description = "Redraws the terminal screen and clears extraneous commands that haven't modified the gameplay test state. Gameplay test data, test summaries, and database entries will not be cleared.",
		Aliases = { "clear", "c" },
		Usage = {
			"-- let's say you've typed a lot of 'next' commands\n-- and you want to clear them to look at the\n-- current gameplay test better...\n"
				.. LOCAL_PLAYER_NAME
				.. ">clear",
		},
	},
	back = {
		Description = "Takes you back to the previous screen. If viewing a gameplay test, takes you to previous test.",
		Aliases = { "back", "b" },
		Usage = {
			"-- take me back!\n" .. LOCAL_PLAYER_NAME .. ">back",
		},
	},

	-- answering gameplay test questions
	yes = {
		Description = "Answers 'yes' to a question in a gameplay test, which marks the question as passing.",
		Aliases = { "yes", "y", "yeah", "yep", "ya", "yesh", "mhm", "ye", "yea", "affirmative", "yuh", },
		Usage = {
			"-- after a test asks you if something works,\n-- and it does actually work\n"
				.. LOCAL_PLAYER_NAME
				.. "/someTest>yes",
			"-- after a test asks you if something works,\n-- and it does NOT work\n"
				.. LOCAL_PLAYER_NAME
				.. "/someTest>no",
		},
	},
	no = {
		Description = "Answers 'no' to a question in a gameplay test, which marks the question as failing.",
		Aliases = { "no", "n", "nope", "noe", "nop", "nah", "na", "negative", },
		Usage = {
			"-- after a test asks you if something works,\n-- and it does NOT work\n"
				.. LOCAL_PLAYER_NAME
				.. "/someTest>no",
			"-- after a test asks you if something works,\n-- and it does actually work\n"
				.. LOCAL_PLAYER_NAME
				.. "/someTest>yes",
		},
	},
	answer = {
		Description = "Generalized version of 'yes' and 'no' commands -- answers a gameplay test question. If `response` is equal to 'yes', it marks the question as a yes/pass, otherwise it marks it as a no/fail.",
		Aliases = { "answer", "ok" },
		Arguments = {
			{
				Name = "response",
				Types = { "string", "boolean", "nil" },
			},
		},
		Usage = {
			"-- answer a gameplay test question as a 'yes'\n" .. LOCAL_PLAYER_NAME .. "/someTest>answer yes",
			"-- answer a gameplay test question as a 'no'\n" .. LOCAL_PLAYER_NAME .. "/someTest>answer no",
		},
	},

	-- test navigation
	next = {
		Description = "Takes you to the next gameplay test. The test you were running before gets paused and can be returned to at any time.",
		Aliases = { "next", "ne", "skip" },
		Usage = {
			"-- skip current test and go to the next one\n" .. LOCAL_PLAYER_NAME .. ">next",
		},
	},
	previous = {
		Description = "Takes you to the previous gameplay test. The test you were running before gets paused and can be returned to at any time.",
		Aliases = { "previous", "prev", "p" },
		Usage = {
			"-- go back to previous test\n" .. LOCAL_PLAYER_NAME .. ">prev",
		},
	},
	index = {
		Description = "Generalized version of 'next' and 'previous' command -- skips you backward or forward a number of gameplay tests.\n\nIf `newTestIndex` is just a number, it will go to the gameplay test with that index.\nIf `newTestIndex` has a '+' or a '-' in front of a number, it will skip forward/backward that number of gameplay tests respectively.",
		Arguments = {
			{
				Name = "newTestIndex",
				Types = { "string", "number" },
			},
		},
		Aliases = { "index", "goto", "test", "go", "setTestIndex" },
	},

	-- summary
	summary = {
		Description = "View list of all gameplay tests in your current session, and their pass/fail/completion scores. Use 'back' to exit summary.",
		Aliases = { "summary", "s", "sum" },
	},

	-- text coloring
	color = {
		Description = "Changes the terminal text color. You can specify a color name or three numbers corresponding to R, G, and B values from 0 to 255.\n\nColor names are also command names! The 'palette' command prints all supported color names.",
		Aliases = { "color", "textcolor", "<any supported color name>" },
		Arguments = {
			{
				Name = "colorName | red",
				Types = { "string", "number" },
			},
			{
				Name = "green",
				Types = { "number", "nil" },
			},
			{
				Name = "blue",
				Types = { "number", "nil" },
			},
		},
		Usage = {
			"-- view a list of all colors\n" .. LOCAL_PLAYER_NAME .. ">palette",
			"-- set text color to cyan\n" .. LOCAL_PLAYER_NAME .. ">color cyan",
			"-- set text color to cyan, but lazily\n" .. LOCAL_PLAYER_NAME .. ">cyan",
			"-- set text color to a specific RGB value\n-- (numbers must be between 0 and 255)\n"
				.. LOCAL_PLAYER_NAME
				.. ">color 123 0 255",
		},
	},
	palette = {
		Description = "Prints a list of default color names to terminal. Type any color name as a command to change the terminal's text color.",
		Aliases = { "palette", "colors" },
		Usage = {
			"-- view a list of all default colors\n" .. LOCAL_PLAYER_NAME .. ">palette",
			"-- set text color to cyan\n" .. LOCAL_PLAYER_NAME .. ">cyan",
		},
	},
	rainbow = {
		Description = "Shifts terminal text color through every hue in the rainbow. `rainbowPeriod` is the number of seconds it takes to complete one full shift through the entire rainbow. Default value is "
			.. tostring(DEFAULT_RAINBOW_PERIOD)
			.. " seconds.\n\nUse the 'stop' command to stop it. `numRainbowSteps` is the number of discrete colors it transitions to. Higher number of steps = more colors and a smoother transition. Default value is "
			.. tostring(DEFAULT_RAINBOW_STEPS)
			.. " colors/steps.",
		Arguments = {
			{
				Name = "rainbowPeriod",
				Types = { "nil", "number" },
			},
			{
				Name = "numRainbowSteps",
				Types = { "nil", "number" },
			},
		},
		Aliases = {
			"rainbow",
			"rain",
			"r",
		},
		Usage = {
			"-- make text start color shifting\n" .. LOCAL_PLAYER_NAME .. ">rainbow",
			"-- oh god make it stop!!\n" .. LOCAL_PLAYER_NAME .. ">stop",
			"-- change the rainbow period to 1 second\n" .. LOCAL_PLAYER_NAME .. ">rainbow 1",
			"-- setting to a normal color will automatically stop rainbowing\n" .. LOCAL_PLAYER_NAME .. ">white",
			"-- make the rainbow shift between only cyan & red\n" .. LOCAL_PLAYER_NAME .. ">rainbow 1 2",
		},
	},
	stop = {
		Description = "Stops text from color shifting. See the 'rainbow' command.",
		Aliases = {
			"stop", "sto",
		},
		Usage = {
			"-- make text start color shifting\n" .. LOCAL_PLAYER_NAME .. ">rainbow",
			"-- oh god make it stop!!\n" .. LOCAL_PLAYER_NAME .. ">stop",
		},
	},

	-- database browsing
	session = {
		Description = "A session begins when a player joins the game, and ends when they leave. Every session (that is at least partially completed) gets saved to a database.\n\nTo discover your current session's unique id, provide no arguments. The id will be nil if the session hasn't been saved yet.\nTo view a summary of any given session in the database, provide the `sessionId` argument.\nTo view the logs of a specific test in a session, provide both the `sessionId` and `testIndex` arguments.",
		Aliases = { "session", "sesh", "se" },
		Arguments = {
			{
				Name = "sessionId",
				Types = { "nil", "integer" },
			},
			{
				Name = "testIndex",
				Types = { "nil", "integer" },
			},
		},
		Usage = {
			"-- to find out your current session's id...\n-- (if it prints nil, your session hasn't been saved yet.)\n"
				.. LOCAL_PLAYER_NAME
				.. ">session",
			"-- to view any session's summary...\n-- (in this case, session #37)\n"
				.. LOCAL_PLAYER_NAME
				.. ">session 37",
			"-- to view the logs of session #37's 2nd test\n" .. LOCAL_PLAYER_NAME .. ">session 37 2",
		},
	},
	browse = {
		Description = "Prints list of most recent test sessions from database. Use the 'session' command to see more detailed info of any given test session. Use the 'more' command to fetch more sessions from the database.",
		Aliases = { "browse", "br" },
		Usage = {
			"-- to see a list of most recent test sessions\n" .. LOCAL_PLAYER_NAME .. ">browse",
			"-- the database only pulls 50 or so sessions at a time.\n-- to look further down the list...\n"
				.. LOCAL_PLAYER_NAME
				.. ">more",
		},
	},
	more = {
		Description = "Fetches more sessions for the database browser. See 'browse' command for more info.",
		Aliases = { "more", "m" },
		Usage = {
			"-- to see a list of most recent test sessions\n" .. LOCAL_PLAYER_NAME .. ">browse",
			"-- the database only pulls 50 or so sessions at a time.\n-- to look further down the list...\n"
				.. LOCAL_PLAYER_NAME
				.. ">more",
		},
	},

	-- database writing
	save = {
		Description = "Any somewhat completed session state will be automatically saved within "
			.. AUTO_SAVE_RATE
			.. " seconds of being changed. However, if you want to manually save your session state, use this command. Note that session states with no finished tests will always fail to save, to avoid database clutter.",
		Aliases = { "save", "sa" },
		Usage = {
			"-- to manually save session state\n" .. LOCAL_PLAYER_NAME .. ">save",
		},
	},
	erase = {
		Description = "Erase a session, or multiple sessions, from the database. Admin permissions required!\n\nTo erase an individual session, provide only the `firstSessionId` argument.To erase a range of multiple sessions, include the `lastSessionId` argument as well.",
		Aliases = { "erase", "e" },
		Arguments = {
			{
				Name = "firstSessionId",
				Types = { "integer" },
			},
			{
				Name = "lastSessionId",
				Types = { "nil", "integer" },
			},
		},
		Usage = {
			"-- to erase an individual session from the database\n-- (in this case, session #37)\n"
				.. LOCAL_PLAYER_NAME
				.. ">erase 37",
			"-- to erase multiple sessions from the database\n-- (in this case, session #37 to session #69)\n"
				.. LOCAL_PLAYER_NAME
				.. ">erase 37 69",
		},
	},
}

-- init | index command metadata by alias
for commandName, CommandMetadata in CANONICAL_COMMAND_METADATA do
	if CommandMetadata.Aliases then
		for i, alias in CommandMetadata.Aliases do
			COMMAND_METADATA[alias] = CommandMetadata
		end
	end
end

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
	local isRunning = true -- this is set to false when GameplayTestRunner is destroyed

	local GameplayTestOrder = {} -- int testIndex --> string testName
	local GameplayTestFunctions = {} -- string testName --> function(TestConsole): nil
	local OrderedTests = {} -- string testName --> int testIndex

	local TestRunnerMaid = Maid()
	local Console
	local TestConsole -- TestConsole wraps Console for use by Gameplay Tests
	local commandLineText = DEFAULT_COMMAND_LINE_PROMPT

	local currentTestIndex = 0 -- index of current test
	local TestThreads = {} -- int testIndex --> thread of GameplayTestFunctions[testIndex]
	local TestOutputs = {} -- int testIndex --> string outputLog (everything ever outputted during the test)
	local userResponse -- a yes/no answer to an "ask" question in a gameplay test

	local viewingSummary = false
	local TestStatusPassing = {} -- int testIndex --> int number of "yes" responses per test
	local TestStatusFailing = {} -- int testIndex --> int number of "no" responses per test

	local viewingTestBrowser = false
	local testBrowserOutput = ""

	local RainbowTweens = {}

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

	-- private | misc
	local function testIsFinished(testIndex)
		--[[
			@return: true if all questions for a given test are answered
		]]
		return TestThreads[testIndex] and coroutine.status(TestThreads[testIndex]) == "dead"
	end
	local function printTitleBlock(AnyConsole, titleString)
		--[[
			@param: Console | TestConsole
				- if you pick TestConsole, it will save it to the current gameplay test's log
				- otherwise nothing gets saved
			@param: string titleString
				- text to be displayed inside the "====="
			@post: prints one of these guys

			=============================================
			=============== HELLO THERE =================
			=============================================
		]]
		titleString = string.upper(titleString)
		local half = ((HORIZONTAL_LINE_WIDTH - string.len(titleString)) / 2) - 1

		-- TestConsole automatically applies a new line character so i have to do this
		-- to avoid an extra newline. I am so sorry.
		local newlineCharacter = if AnyConsole == TestConsole then "" else "\n"

		AnyConsole.output(newlineCharacter .. string.rep("=", HORIZONTAL_LINE_WIDTH))
		AnyConsole.output(
			newlineCharacter
				.. string.rep("=", math.floor(half))
				.. " "
				.. titleString
				.. " "
				.. string.rep("=", math.ceil(half))
		)
		AnyConsole.output(newlineCharacter .. string.rep("=", HORIZONTAL_LINE_WIDTH))
	end
	local function printHorizontalLine()
		--[[
			@post: prints one of these guys
			=============================================
		]]
		Console.output("\n" .. string.rep("=", HORIZONTAL_LINE_WIDTH))
	end

	-- public | test output commands
	local function logCommand(commandName)
		--[[
			@param: string commandName
			@post: saves user command to current test's output log
			(this is actually a private method but it's only for the TestCommands so...)
		]]
		local text = "\n" .. commandLineText .. commandName
		TestOutputs[currentTestIndex] = (TestOutputs[currentTestIndex] or "") .. text
	end
	local function redrawCurrentTest()
		--[[
			@post: clear screen & output current test's output log
		]]
		viewingSummary = false
		viewingTestBrowser = false
		Console.clear()
		Console.output(TestOutputs[currentTestIndex])
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
			newTestIndex = currentTestIndex + tonumber(string.sub(newTestIndex, 2, -1))
		elseif string.sub(newTestIndex, 1, 1) == "-" then
			-- support symbolic decrementing
			newTestIndex = currentTestIndex - tonumber(string.sub(newTestIndex, 2, -1))
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
		currentTestIndex = newTestIndex
		redrawCurrentTest()

		-- ask server to initialize whatever it needs to for this test
		local clientTestName = GameplayTestOrder[currentTestIndex] -- this nonsense VVV allows us to reuse a server function per multiple client tests
		local serverTestName = TEST_NAME_TO_SERVER_INITIALIZER[clientTestName] or clientTestName
		InitializeGameplayTestRemote:InvokeServer(serverTestName)

		-- resume test thread if it isn't finished
		if coroutine.status(TestThreads[currentTestIndex]) == "dead" then
			TestConsole.setCommandLinePrompt()
			return
		end
		TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. GameplayTestOrder[currentTestIndex] .. ">")
		if TestOutputs[currentTestIndex] == nil then
			-- we only need to resume if the test thread hasn't been initialized yet
			coroutine.resume(TestThreads[currentTestIndex])
		end
	end
	local function nextTest()
		--[[
			@post: moves onto next gameplay test (testIndex += 1)
		]]

		-- display cheeky message if we're at the end of the tests
		if currentTestIndex >= #GameplayTestOrder then
			Console.output("\n" .. END_OF_TESTS_MESSAGE .. "\n")
			return
		end
		setTestIndex(nil, "+1")
	end
	local function prevTest()
		--[[
			@post: moves back to previous gameplay test (testIndex -= 1)
		]]
		-- display cheeky message if we're at the very beginning of the tests
		if currentTestIndex <= 1 then
			Console.output("\n" .. BEGINNING_OF_TESTS_MESSAGE .. "\n")
			return
		end
		setTestIndex(nil, "-1")
	end

	-- public | response commands for "ask" prompts
	local function answerQuestion(_, response)
		--[[
			@param: Console (this is how Terminal passes args to command functions -- we don't need it in this case.)
			@param: boolean | string response
			@post: runs current gameplay test until next "ask" prompt
			@post: if at end of current test, moves onto next test
		]]

		-- convert response to boolean in case of use by command line
		-- idk why i care about this tbh
		if typeof(response) ~= "boolean" then
			response = (response == "yes" or response == "true")
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
		if currentTestIndex > #GameplayTestOrder then
			Console.output("\n\n" .. END_OF_TESTS_MESSAGE .. "\n")
			return
		end

		-- move onto next test if current one is finished
		if testIsFinished(currentTestIndex) then
			setTestIndex(nil, "+1") -- go onto next test
			return
		end

		-- actually run the next step of the test
		userResponse = response
		logCommand(if response then "yes" else "no")

		TestConsole.output()
		coroutine.resume(TestThreads[currentTestIndex])
	end
	local function yes(_)
		--[[
			@post: gives a "yes" response to the last ask and resumes next step in current test
		]]
		answerQuestion(_, true)
	end
	local function no(_)
		--[[
			@post: gives a "no" response to the last ask and resumes next step in current test
		]]
		answerQuestion(_, false)
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

			if currentTestIndex == i then
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

	-- public | text coloring commands
	local function stopRainbowing(_)
		--[[
			@post: stop color shifting!! (see rainbow)
		]]
		for i, Tween in RainbowTweens do
			Tween:Cancel()
			Tween:Destroy()
		end
		RainbowTweens = {}
	end
	local function rainbow(_, rainbowPeriod, numRainbowSteps)
		--[[
			@param: Console
			@param: nil | number rainbowPeriod
				- how long it takes to complete one shift.
			@param: nil | number numRainbowSteps
				- how many "steps" the color wheel is divided into.
				- more steps == smoother transitions & more granular color shifting
			@post: shifts text through every hue in color wheel
		]]

		stopRainbowing()

		rainbowPeriod = tonumber(rainbowPeriod) or DEFAULT_RAINBOW_PERIOD
		numRainbowSteps = tonumber(numRainbowSteps) or DEFAULT_RAINBOW_STEPS
		local rainbowStepPeriod = rainbowPeriod / numRainbowSteps

		-- build tweens
		for i = 1, numRainbowSteps do
			RainbowTweens[i] =
				TweenService:Create(Console.TextBox, TweenInfo.new(rainbowStepPeriod, Enum.EasingStyle.Linear), {
					TextColor3 = Color3.fromHSV(i / numRainbowSteps, 1, 1),
				})
			if i > 1 then
				RainbowTweens[i - 1].Completed:Connect(function()
					if RainbowTweens[i] then
						RainbowTweens[i]:Play()
					end
				end)
			end
		end
		RainbowTweens[numRainbowSteps].Completed:Connect(function()
			if RainbowTweens[1] then
				RainbowTweens[1]:Play()
			end
		end)

		-- init (the defer helps with double-calls to rainbow some... it's kinda buggy :/)
		task.defer(function()
			RainbowTweens[1]:Play()
		end)
	end
	local function setTextColor(_, r, g, b)
		--[[
			@param: Console (we don't need it)
			@param: string color
		]]

		stopRainbowing()

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

	-- public | database browser commands
	local function redrawSessionBrowser(_)
		--[[
			@post: refreshes output with all sessions
		]]
		Console.clear()
		Console.output("\nTEST SESSION DATABASE\n")
		Console.output(testBrowserOutput)
		Console.output("\n")
	end
	local function browseMoreSessionTimestamps(_, startOver)
		--[[
			@param: Console (unnecessary)
			@param: any | nil startOver
				- if truthy, server will delete its cache and start from the beginning
		]]
		if not viewingTestBrowser then
			return
		end

		Console.output("\nFetching tests from database...")
		local SessionData = BrowseSessionTimestampsRemote:InvokeServer(startOver)
		if SessionData == nil or #SessionData <= 0 then
			Console.output("\nNo more tests\n")
			return
		end

		for i, Session in SessionData do
			local sessionId, sessionTimestamp, UserNames, numPassing, numFailing, numTotal = unpack(Session)
			local SessionDateTime = DateTime.fromUnixTimestamp(sessionTimestamp)

			sessionId = tostring(sessionId)
			sessionId = "#"
				.. sessionId
				.. string.rep(" ", math.max(MAX_SESSION_ID_STRING_LENGTH - string.len(sessionId), 0) + 1)
				.. " "

			sessionTimestamp = SessionDateTime:FormatLocalTime("l", "en-us")
				.. " "
				.. SessionDateTime:FormatLocalTime("LT", "en-us")
				.. " "

			local userName = ""
			if UserNames then
				userName = tostring(UserNames[1]) .. " "
				if #UserNames > 1 then
					userName = userName .. "+" .. tostring(#UserNames - 1) .. " "
				end
			end

			local testSummary = ""
			if numPassing and numFailing and numTotal then
				testSummary = tostring(math.round(10 ^ 2 * numPassing / numTotal))
					.. "% passing "
					.. tostring(math.round(10 ^ 2 * (numPassing + numFailing) / numTotal))
					.. "% complete "
			end

			testBrowserOutput = testBrowserOutput .. "\n" .. sessionId .. sessionTimestamp .. userName .. testSummary
		end
		redrawSessionBrowser()
	end
	local function browseSessionTimestamps(_)
		viewingTestBrowser = true
		testBrowserOutput = ""
		browseMoreSessionTimestamps(_, true)
	end

	-- public | basic database read commands
	local function printTestLog(_, sessionId, testIndex)
		--[[
			@param: string | integer sessionId
			@param: string | integer testIndex
			@post: output that test's log from the database
		]]

		-- sanity check
		sessionId = tonumber(sessionId)
		if sessionId == nil then
			error("Session id must be an integer!")
		end

		testIndex = tonumber(testIndex)
		if testIndex == nil then
			error("Test index must be an integer!")
		end

		-- database query
		local testLog = GetTestLogRemote:InvokeServer(sessionId, testIndex)
		if testLog == nil then
			Console.output(
				"\nFailed to get Test Log for Session #"
					.. tostring(sessionId)
					.. " Test #"
					.. tostring(testIndex)
					.. "\n"
			)
			return
		end

		-- dump data in console
		Console.clear()
		printTitleBlock(Console, "SESSION #" .. tostring(sessionId) .. " TEST #" .. tostring(testIndex))
		Console.output(testLog)
		printTitleBlock(Console, "BROWSING MODE")
		Console.output("\n")
	end
	local function printSessionSummary(_, sessionId)
		--[[
			@param: string | integer sessionId
			@post: outputs every test's score in a session
		]]

		-- sanity check
		sessionId = tonumber(sessionId)
		if sessionId == nil then
			error("Session id must be an integer!")
		end

		-- database query
		local SessionData = GetSessionSummaryRemote:InvokeServer(sessionId)
		if SessionData == nil then
			Console.output("\nFailed to get summary for session #" .. tostring(sessionId) .. "\n")
		end

		-- data massaging
		local Timestamp = DateTime.fromUnixTimestamp(SessionData.Timestamp)

		-- output
		Console.clear()
		Console.output("\n=============================================================")
		Console.output("\n================= SESSION #" .. tostring(sessionId) .. " SUMMARY")
		Console.output("\n=============================================================")

		Console.output("\n")
		Console.output("\n" .. Timestamp:FormatLocalTime("LLLL", "en-us"))
		Console.output(
			"\nPassing: "
				.. tostring(SessionData.Passing)
				.. " Failing: "
				.. tostring(SessionData.Failing)
				.. " Total: "
				.. tostring(SessionData.Total)
		)

		if SessionData.UserNames then
			Console.output("\n")
			Console.output("\nUsers")
			for _, userName in SessionData.UserNames do
				Console.output("\n    " .. tostring(userName))
			end
		end

		Console.output("\n")
		for testIndex, TestScore in SessionData.Summary do
			Console.output(
				"\n[Test #"
					.. tostring(testIndex)
					.. "] - Passing: "
					.. tostring(TestScore.Passing)
					.. " Failing: "
					.. tostring(TestScore.Failing)
					.. " Total: "
					.. tostring(TestScore.Total)
			)
		end

		Console.output("\n\n=============================================================")
		Console.output("\n=================== BROWSING MODE ===========================")
		Console.output("\n=============================================================\n")
	end
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
			Console.output(
				"\nSession #"
					.. tostring(sessionId)
					.. " ended on "
					.. LocalDateTime:FormatLocalTime("LLLL", "en-us")
					.. "\n"
			)
		else
			Console.output("\nSession #" .. tostring(sessionId) .. " doesn't exist\n")
		end
	end
	local function session(_, sessionId, testIndex)
		--[[
			@param: Console (unnecessary)
			@param: int | string | nil sessionId
			@post: if sessionId is nil, prints the current session id of this game/test session
		]]
		if testIndex then
			printTestLog(_, sessionId, testIndex)
			return
		end
		if sessionId then
			printSessionSummary(_, sessionId)
			return
		end
		printSessionId()
	end

	-- public | database write commands
	local function saveSessionState(_)
		--[[
			@post: saves test session state to database (no outputting to console)
			@return: bool successful
		]]

		-- build session state
		local SessionState = {
			Passing = 0,
			Failing = 0,
			Total = 0,
			Summary = {}, -- { int testIndex --> { Passing: int, Failing: int, Total: int } }
			Logs = TestOutputs,
		}

		for testIndex, numPassing in TestStatusPassing do
			local numFailing = TestStatusFailing[testIndex]
			local numTotal = numFailing + numPassing

			SessionState.Summary[testIndex] = {
				Passing = numPassing,
				Failing = numFailing,
				Total = numTotal,
			}

			if testIsFinished(testIndex) then
				if numPassing >= numTotal then
					SessionState.Passing += 1
				else
					SessionState.Failing += 1
				end
			end
			SessionState.Total += 1
		end

		-- ask server to save it for us >_<
		return SaveSessionRemote:InvokeServer(SessionState)
	end
	local function saveCommand(_)
		--[[
			@post: saves test session state to database
			@post: outputs to console
		]]
		Console.output("\nSaving...")
		local success = saveSessionState(_)
		if success then
			Console.output("\nSaved successfully.\n")
		else
			Console.output("\nFailed to save.\n")
		end
	end
	local function eraseSession(_, minSessionId, maxSessionId)
		--[[
			@param: Console (unnecessary)
			@param: int | string minSessionId
			@param: nil | int | string maxSessionId
			@post: erases a given session or, if maxSessionId is provided, a range of sessions
		]]

		-- sanity check
		minSessionId = tonumber(minSessionId)
		if minSessionId == nil then
			error("Session id must be an integer!")
		end
		if maxSessionId then
			maxSessionId = tonumber(maxSessionId)
			if maxSessionId == nil then
				error("Both session id's must be integers!")
			end
		end

		-- immediate feedback for user
		if maxSessionId then
			Console.output(
				"\nErasing Sessions from #" .. tostring(minSessionId) .. " to #" .. tostring(maxSessionId) .. "..."
			)
		else
			Console.output("\nErasing Session #" .. tostring(minSessionId) .. "...")
		end

		-- database write
		local success = EraseSessionRemote:InvokeServer(minSessionId, maxSessionId)
		if success then
			Console.output("\nSuccess!\n")
		else
			Console.output("\nIt didn't work.\n")
		end
	end

	-- public | universal commands
	local function back()
		--[[
			@post: if viewing summary, simply exits summary (also applies to database browser).
			@post: otherwise, goes to previous test
		]]
		if viewingSummary or viewingTestBrowser then
			-- exit summary or browser view
			redrawCurrentTest()
		else
			prevTest()
		end
	end
	local function clear()
		--[[
			@post: redraws whatever test, summary, or browser you're looking at
		]]
		if viewingSummary then
			viewSummary()
		elseif viewingTestBrowser then
			redrawSessionBrowser()
		else
			redrawCurrentTest()
		end
	end
	local function help(_, anyCommandName)
		--[[
			@param: nil | string commandName
			@post: outputs list of all commands to console
			@post: if command name specified, specifies how to use that command
		]]

		-- help with a specific command (RETURNS)
		if anyCommandName then
			anyCommandName = tostring(anyCommandName)

			-- what if that command doesn't exist? (RETURNS)
			local CommandMetadata = COMMAND_METADATA[anyCommandName]
			if CommandMetadata == nil then
				-- it might be a color name, since color names are commands too.
				if DEFAULT_TEXT_COLORS[anyCommandName] then
					help(_, "color")
					return
				end

				Console.output("\nThere's no command named \"" .. tostring(anyCommandName) .. '"\n')
				return
			end

			Console.output("\n")
			printTitleBlock(
				Console,
				"'" .. (if CommandMetadata.Aliases then CommandMetadata.Aliases[1] else anyCommandName) .. "' command"
			)

			if CommandMetadata.Description then
				Console.output("\n")
				Console.output("\n" .. CommandMetadata.Description)
			end

			if CommandMetadata.Arguments then
				Console.output("\n")
				Console.output("\nARGUMENTS")
				for _, ArgumentData in CommandMetadata.Arguments do
					Console.output("\n    " .. ArgumentData.Name .. ": ")
					for i, typeName in ArgumentData.Types do
						Console.output(typeName .. " ")
						if i < #ArgumentData.Types then
							Console.output("| ")
						end
					end
				end
				for argName, ArgTypes in CommandMetadata.Arguments do
				end
			end

			if CommandMetadata.Aliases then
				Console.output("\n")
				Console.output("\nALIASES\n    ")
				for i, alias in CommandMetadata.Aliases do
					if i > 1 then
						Console.output(", ")
					end
					Console.output(alias)
				end
			end

			if CommandMetadata.Usage then
				Console.output("\n")
				Console.output("\nEXAMPLE USAGE")
				for i, example in CommandMetadata.Usage do
					Console.output("\n")
					local Lines = string.split(example, "\n")
					for j, line in Lines do
						Console.output("\n    " .. line)
					end
				end
			end

			Console.output("\n")
			printHorizontalLine()
			Console.output("\n")

			return
		end

		-- list all commands in a sweet, sweet grid
		Console.output("\n")
		printTitleBlock(Console, "ALL COMMANDS")
		Console.output("\n")

		local i = 0
		for commandName, _ in CANONICAL_COMMAND_METADATA do
			if i % NUM_HELP_COLUMNS == 0 then
				Console.output("\n")
			end
			i += 1
			Console.output(commandName .. string.rep(" ", HELP_COLUMN_WIDTH - string.len(commandName)))
		end

		Console.output("\n")
		printHorizontalLine()
		Console.output('\n\nType "help" (without quotes) followed by the name of a command for specific help.\n')
	end

	-- public | encapsulate all commands
	local TestCommands = {
		--[[
			string commandName --> function(Console, ...)

			Only put the canonical command name here.
			The aliases are automatically applied below.
		]]
		-- universal
		back = back,
		clear = clear,
		help = help,

		-- test navigation
		index = setTestIndex,
		next = nextTest,
		previous = prevTest,

		-- test responses
		yes = yes,
		no = no,
		answer = answerQuestion,

		-- summary
		summary = viewSummary,

		-- text colors
		color = setTextColor,
		palette = viewTextColors,
		rainbow = rainbow,
		stop = stopRainbowing,

		-- database browsing
		session = session,
		browse = browseSessionTimestamps,
		more = browseMoreSessionTimestamps,

		-- database writing
		save = saveCommand,
		erase = eraseSession,
	}
	for commandName, commandFunction in TestCommands do
		local CommandMetadata = COMMAND_METADATA[commandName]
		if CommandMetadata and CommandMetadata.Aliases then
			for i, alias in CommandMetadata.Aliases do
				TestCommands[alias] = commandFunction
			end
		end
	end
	for textColor, _ in DEFAULT_TEXT_COLORS do
		-- every default text color is a command
		-- beware of collisions!
		TestCommands[textColor] = function()
			setTextColor(Console, textColor)
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
		TestOutputs[currentTestIndex] = (TestOutputs[currentTestIndex] or "") .. text
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
			TestStatusPassing[currentTestIndex] += 1
		else
			TestStatusFailing[currentTestIndex] += 1
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
	TestRunnerMaid(function()
		isRunning = false
	end)

	-- create a thread per test function
	for i, testName in GameplayTestOrder do
		-- init question summary
		TestStatusPassing[i] = 0
		TestStatusFailing[i] = 0

		-- init test fn. thread
		local testFunction = GameplayTestFunctions[testName]
		TestThreads[i] = coroutine.create(function()
			TestConsole.clear()
			printTitleBlock(TestConsole, "TEST #" .. tostring(i) .. ': "' .. testName .. '"')
			TestConsole.output() -- newline

			TestConsole.setCommandLinePrompt(LocalPlayer.Name .. "/" .. testName .. ">")
			testFunction(TestConsole)

			printTitleBlock(TestConsole, "FINISHED TEST #" .. tostring(i))

			TestConsole.output()
			TestConsole.output("" .. testName .. " score:")
			TestConsole.output("    " .. tostring(TestStatusPassing[i]) .. " passing")
			TestConsole.output("    " .. tostring(TestStatusFailing[i]) .. " failing")
			TestConsole.output("    " .. tostring(TestStatusFailing[i] + TestStatusPassing[i]) .. " total")
			TestConsole.output()

			if i < #GameplayTestOrder then
				TestConsole.output("Type 'next' (without quotes) to continue.\n")
			else
				TestConsole.output("There are no more tests. You did it!")
				TestConsole.output("Type 'summary' (without quotes) to see your results.\n")
			end

			TestConsole.setCommandLinePrompt() -- defaults to "PlayerName>"
		end)
	end

	-- auto-save
	task.spawn(function()
		while isRunning do
			task.wait(AUTO_SAVE_RATE)
			saveSessionState()
		end
	end)

	-- automatically begin running tests
	nextTest()
	Console.initialize() -- i think this yields...

	-- this object exposes Terminal's TextBox and
	-- allows you to destroy the whole thing
	-- with :Destroy() or :destroy()
	return setmetatable({
		TextBox = Console.TextBox,
	}, {
		__index = TestRunnerMaid,
	})
end
