rockspec_format = "3.0"
package = "algo"
version = "scm-1"
source = {
   url = "git+https://github.com/moonlibs/algo.git"
}
description = {
   homepage = "https://github.com/moonlibs/algo.git",
   license = "GPL",
   summary = "Collection of data structures designed for Lua in Tarantool",
   detailed = [[
      Module moonlibs/algo provides set of fastest pure-lua data structures such as
      `heap` and `rlist`, and more complex `rmean` without any external dependencies.
   ]],
}
dependencies = {
   "lua ~> 5.1"
}
test_dependencies = {
   "luacheck",
   "luatest",
   "luacov",
   "luacov-coveralls",
   "luacov-console",
   "luabench",
}
test = {
   type = 'command',
   command = 'make test',
}
build = {
   type = "builtin",
   modules = {
      algo = "algo.lua",
      ["algo.rlist"] = "algo/rlist.lua",
      ["algo.rmean"] = "algo/rmean.lua",
      ["algo.heap"] = "algo/heap.lua",
      ["algo.odict"] = "algo/odict.lua",
      ["algo.skiplist"] = "algo/skiplist.lua",
   }
}
