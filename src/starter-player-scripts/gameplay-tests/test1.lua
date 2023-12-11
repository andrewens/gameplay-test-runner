return function(TestConsole)
	-- #1
	TestConsole.output("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus eu nisl mauris.")
	local yes = TestConsole.ask("Ut at commodo massa?")
	if yes then
		TestConsole.output("Hooray!")
	else -- no
		TestConsole.output("Aw :(")
	end

	-- #2
	TestConsole.output("Aenean nec tellus est.")
	yes = TestConsole.ask("Sed faucibus tincidunt suscipit?")
	if yes then
		TestConsole.output("Excellent.")
	else
		TestConsole.output("Darnit.")
	end

	-- #3
	TestConsole.output("Duis in enim ac arcu semper euismod. Integer nec cursus neque.")
	yes = TestConsole.ask("Nam eget elit in lectus semper placerat?")
	if yes then
		TestConsole.output("I am overjoyed.")
	else
		TestConsole.output("I am distraught with fear and anger.")
	end

	-- #4
	TestConsole.output("Pellentesque a pulvinar nisi. Morbi maximus sit amet dolor at blandit.")
	yes = TestConsole.ask("Curabitur nisl erat, accumsan tempus pretium vel, consequat id purus?")
	if yes then
		TestConsole.output("By golly we did it.")
	else
		TestConsole.output("I'm giving up programming.")
	end
end
