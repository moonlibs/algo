local t = require 'luatest' --[[@as luatest]]
local g = t.group('heap')

local heap = require 'algo.heap'

function g.test_heap_module()
	t.assert_type(heap, 'table', 'heap module must be a table')
	t.assert_type(heap.new, 'function', 'heap must export function new')
	t.assert_is(require 'algo'.heap, require 'algo.heap', "heap module can be required from algo and algo.heap")
end

function g.test_priority_heap()
	local h = heap.new(function (a, b)
		return a.priority < b.priority
	end)

	t.assert_type(h, 'table', 'instantiated heap is a table')

	h:push({ priority = 20 })
	h:push({ priority = 10 })

	t.assert_is(h:count(), 2, 'heap:count - 2 items')

	local x = h:pop()
	t.assert_type(x, 'table', 'heap:pop - table')
	t.assert_is(x.priority, 10, 'heap:pop is minheap')

	x = h:pop()
	t.assert_type(x, 'table', 'heap:pop - table')
	t.assert_is(x.priority, 20, 'heap:pop is minheap')
	t.assert_is(h:count(), 0, 'heap:count - 0 items')
end

function g.test_priority_order_heap()
	local h = heap.new(function (a, b)
		if a.priority == b.priority then
			return a.order > b.order
		end
		return a.priority < b.priority
	end)

	h:push{priority = 20, order = 1}
	h:push{priority = 10, order = 2}
	h:push{priority = 10, order = 3}
	h:push{priority = 20, order = 4}

	t.assert_is(h:pop().order, 3, 'minheap order 3')
	t.assert_is(h:pop().order, 2, 'minheap order 2')
	t.assert_is(h:pop().order, 4, 'minheap order 4')
	t.assert_is(h:pop().order, 1, 'minheap order 1')

	t.assert_is(h:pop(), nil, 'empty heap - pops nil')
end

function g.test_heap_ints()
	local h = heap.new(function (a, b)
		return a[1] < b[1]
	end)

	local idx = {}
	local nodes = {}
	for _, n in ipairs({1, 2, 100, 3, 4, 200, 300}) do
		local node = {n}
		idx[n] = node
		table.insert(nodes, node)
		h:push(node)
	end

	h:remove_try(idx[2])
	t.assert_equals(h.data, { idx[1], idx[3], idx[100], idx[300], idx[4], idx[200] }, 'internal heap structure')
end

function g.test_heap_update()
	local h = heap.new(function (a, b)
		return a[1] < b[1]
	end)

	local idx = {}
	local nodes = {}
	for i, n in ipairs({1, 10, 10, 100, 100, 100, 100}) do
		local node = {n}
		idx[i] = node
		table.insert(nodes, node)
		h:push(node)
	end

	idx[2][1] = 300
	h:update(idx[2])

	t.assert_is(h:top()[1], 1, 'minheap - 1')
	h:remove_top()
	t.assert_is(h:top()[1], 10, 'minheap - 10')
	h:remove_top()
	t.assert_is(h:top()[1], 100, 'minheap - 100')
	h:remove_top()
	t.assert_is(h:top()[1], 100, 'minheap - 100')
	h:remove_top()
	t.assert_is(h:top()[1], 100, 'minheap - 100')
	h:remove_top()
	t.assert_is(h:top()[1], 100, 'minheap - 100')
	h:remove_top()
	t.assert_is(h:top()[1], 300, 'minheap - 300')
	h:remove_top()
	h:remove_top()
end
