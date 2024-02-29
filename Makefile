.PHONY := all test

test-deps:
	tarantoolctl rocks test --prepare

luacheck: test-deps
	.rocks/bin/luacheck .

luatest: test-deps
	.rocks/bin/luatest -c -v --coverage

coverage: test-deps
	.rocks/bin/luacov-console $$(pwd) && .rocks/bin/luacov-console -s

test: test-deps luacheck luatest coverage

bench: test-deps
	.rocks/bin/luabench -d 10000x .