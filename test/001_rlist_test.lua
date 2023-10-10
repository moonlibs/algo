local t = require 'luatest' --[[@as luatest]]
local g = t.group('rlist')

local rlist = require 'algo.rlist'

function g.test_rlist_module()
	t.assert_type(rlist, 'table', 'rlist module must be a table')
	t.assert_type(rlist.new, 'function', 'rlist must export function new')
	t.assert_is(require 'algo'.rlist, require 'algo.rlist', "rlist module can be required from algo and algo.rlist")
end

function g.test_rlist_push_pop()
	local rl = rlist.new()
	t.assert_type(rl, 'table', 'rlist.new must return table')
	t.assert_equals(rl.count, 0, 'newly created rlist must contain field count==0')

	local node = {}
	rl:push(node)

	t.assert_equals(rl.count, 1, "rlist:push must increment count")
	t.assert_is(rl.last, node, 'rlist.last must be the same as newly inserted node')
	t.assert_is(rl.first, node, 'rlist.first must be the same as newly inserted node')

	t.assert_covers(node, {}, 'first node in the list does not have any links')

	local pop = rl:pop()
	t.assert_equals(rl.count, 0, 'rlist:pop decrements count')
	t.assert_is(pop, node, 'rlist:pop returns exactly the same node')

	local none = rl:pop()

	t.assert_equals(rl.count, 0, 'rlist:pop on empty does not change count')
	t.assert_is(none, nil, 'rlist:pop from empty list returns nothing')

	for i = 1, 5 do
		rl:push({i = i})
	end
	t.assert_equals(rl.count, 5, 'rlist:push 5 nodes')

	local n = 0
	while true do
		local p = rl:pop()
		if not p then break end
		t.assert_type(p, 'table', 'rlist:pop returns only tables')
		t.assert_is(p.i, 5-n, 'rlist:pop returns items from the and (stack behaviour)')
		n = n + 1
	end

	t.assert_is(n, 5, 'rlist:pop extracted exactly 5 items')
	t.assert_is(rl.count, 0, 'rlist.count is 0 after draining rlist')

	for i = 1, 5 do
		rl:add_head({ i = i })
	end
	t.assert_equals(rl.count, 5, 'rlist:add_head 5 nodes')

	n = 0
	for _, x in rl:pairs() do
		t.assert_is(x.i, 5-n, 'rl:pairs loop forward')
		n = n+1
	end
	t.assert_equals(n, 5, 'rl:pairs must be executed exactly 5 times')

	n = 0
	for _, x in rl:rpairs() do
		n = n+1
		t.assert_is(x.i, n, 'rl:rpairs loop backwards')
	end
	t.assert_equals(n, 5, 'rl:pairs must be executed exactly 5 times')

	n = 0
	while true do
		local p = rl:remove_first()
		if not p then break end
		t.assert_is(p.i, 5-n, 'rl:pairs loop forward')
		n = n + 1
	end
	t.assert_equals(n, 5, 'rl:remove_first executed exactly 5 times')
end
