.PHONY := all test

test-deps:
	tt rocks test --prepare

luacheck:
	.rocks/bin/luacheck .

luatest:
	.rocks/bin/luatest -c -v --coverage

coverage:
	.rocks/bin/luacov-console $$(pwd) && .rocks/bin/luacov-console -s

test: test-deps luacheck luatest coverage

bench:
	.rocks/bin/luabench -d 10000x .