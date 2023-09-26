rockspec_format = "3.0"
package = "algo"
version = "scm-1"
source = {
   url = "git+https://github.com/moonlibs/algo.git"
}
description = {
   homepage = "https://github.com/moonlibs/algo.git",
   license = "GPL"
}
dependencies = {
   "lua ~> 5.1"
}
build = {
   type = "builtin",
   modules = {
      algo = "algo.lua",
      ["algo.rlist"] = "algo/rlist.lua",
      ["algo.rmean"] = "algo/rmean.lua",
      ["algo.heap"] = "algo/heap.lua"
   }
}
