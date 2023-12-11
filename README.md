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
* ~~Support yes/no responses from "ask"~~ `Dec 11, 2023`
* ~~View test state summary page~~ `Dec 11, 2023`
* Support running server code per test
* Browse all test results from database
* Option to restart a test
* Auto-start the gameplay test on entry
* Help command
* Support player leaving comments
* Organize test database by place version, or date
