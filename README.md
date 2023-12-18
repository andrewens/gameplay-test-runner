# gameplay-test-runner
Test-driven development for complex game features & environments. 

Instead of defining automated unit tests, you create sandboxes for the player to test the game, forcing the developer to define what the features are supposed to do, and conveniently setting up tests and tracking what works/doesn't for effective test-driven development.

It's all through a Command Line Interface, btw.

***Built using Rojo***

### TODO
* ~~Test control flow (TestConsole.ask, TestConsole.output)~~ `Dec 10, 2023`
  * ~~Step between questions (coroutine.yield/resume)~~
  * ~~Test header & footer~~
  * ~~Clear output when starting a new test~~
* ~~Command line prompt changes per test; PlayerName/Test X>~~ `Dec 10, 2023`
* ~~Go to previous & next test~~ `Dec 10, 2023`
* ~~Auto-start the gameplay test on entry~~ `Dec 10, 2023`
* ~~Support yes/no responses from "ask"~~ `Dec 11, 2023`
* ~~View test state summary page~~ `Dec 11, 2023`
* ~~Allow user to change color of text~~ `Dec 11, 2023`
* ~~Support running server code per test~~ `Dec 11, 2023`
* ~~Browse other users' test results from database~~ `Dec 18, 2023`
  * ~~Organize test database by place version, or date~~ `Dec 13, 2023`
  * ~~Save test on exit~~ `Dec 13, 2023`
  * ~~Assign test id on beginning~~ `Dec 13, 2023`
  * ~~Browse all sessions~~ `Dec 13, 2023`
  * ~~Attach test username to each session in browser~~ `Dec 17, 2023`
  * ~~...and its % passing and % completed~~ `Dec 17, 2023`
  * ~~Browse summary of a session~~ `Dec 18, 2023`
  * ~~Browse individual tests of a session~~ `Dec 18, 2023`
* ~~Don't save 0% completed tests~~ `Dec 18, 2023`
* ~~Display users in session summary!~~ `Dec 18, 2023`
* ~~Erase tests~~ `Dec 18, 2023`
* Support player leaving comments
* Option to restart a test
* Help command
* Support returning Maid tasks from server test initializers
* Dump error messages in test output (?)


### WISHLIST
* Exit test-response mode after viewing a session summary
* Display session database like a spreadsheet with column names and good spacing
* Redefine the interface (and Terminal's interface) to just directly 
  interact with GUI properties as if it were another ROBLOX GUI instance
* Terminal supports a function to interpret commands
* Implement custom cursor with Terminal to fix roblox cursor bugs
* Terminal window system
  * Minimize to a taskbar
  * Drag to resize
  * Drag top bar to move
  * X to close
* Specify a (rich) text color for Console.output 
* Status bar on bottom of terminal window
