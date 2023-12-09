-- dependency
local Terminal = require(script:FindFirstChild("Terminal"))
local Maid = require(script:FindFirstChild("Maid"))

-- public
return function(ScrollingFrame, GameplayTests, CONFIG)
	--[[
        @param: Instance ScrollingFrame
        @param: table GameplayTests
            { int i --> Instance (should have child module scripts) }
            { string testName --> function(TestConsole) }
        @param: table Config {
            PRIORITY_TESTS:             nil | { int i --> string testName }
            ONLY_RUN_PRIORITY_TESTS:    nil | boolean
        }
        @return: Maid
    ]]

	local TestRunnerMaid = Maid()

	local TestTerminal = Terminal(ScrollingFrame, {})
	TestRunnerMaid(TestTerminal)

	TestTerminal.initialize()

	return TestRunnerMaid
end
