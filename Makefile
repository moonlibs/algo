.PHONY := all test

luacheck:
	.rocks/bin/luacheck .

luatest:
	.rocks/bin/luatest -c -v --coverage

coverage:
	.rocks/bin/luacov-console $$(pwd) && .rocks/bin/luacov-console -s

test: luacheck luatest coverage

bench:
	tarantool -jon luabench.lua -d 10000x .