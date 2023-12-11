return function(TestConsole)
	-- #1
	TestConsole.output("Proin accumsan sapien orci, eget hendrerit purus ullamcorper a.")
	local yes = TestConsole.ask("Morbi id cursus orci?")
	if yes then
		TestConsole.output("Yay")
	else
		TestConsole.output("Aww man :(")
	end

	-- #2
	TestConsole.output("In non lacus vel ante ullamcorper cursus vel nec nisl.")
	yes = TestConsole.ask("Nunc tincidunt lacus sed dui elementum, facilisis pulvinar odio scelerisque?")
	if yes then
		TestConsole.output("Yay")
	else
		TestConsole.output("Aww man :(")
	end

	-- #3
	TestConsole.output("Integer nibh ligula, auctor id nisl id, luctus posuere mi.")
	yes = TestConsole.ask("Integer consequat lobortis enim ut iaculis?")
	if yes then
		TestConsole.output("Yay")
	else
		TestConsole.output("Aww man :(")
	end

	-- #4
	TestConsole.output("Mauris id vestibulum mi. Vestibulum eget odio mi.")
	yes = TestConsole.ask("Phasellus id ex vel arcu ullamcorper faucibus?")
	if yes then
		TestConsole.output("Yay")
	else
		TestConsole.output("Aww man :(")
	end
end
