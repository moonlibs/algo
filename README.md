# algo: Collection of data structures designed for Lua in Tarantool

[![Coverage Status](https://coveralls.io/repos/github/moonlibs/algo/badge.svg?branch=master)](https://coveralls.io/github/moonlibs/algo?branch=master)

## Status

Latest release `0.1.0`

## Install

### Adding Library as a Dependency

#### 1. Update `.rocks/config-5.1.lua`

```lua
rocks_servers = {
    "https://moonlibs.org",
    "https://moonlibs.github.io/rocks",
    "https://rocks.tarantool.org",
    -- Add any existing repositories here
}
```

Specify `algo` as a dependency in your `rockspec` file.

```lua
dependencies = {
  "algo ~> 0.1.0"
}
```

Install library `algo`

```bash
tt rocks install --only-deps
# or
tarantoolctl rocks install --only-deps
```

## Doubly Linked List (algo.rlist)

**Key Features:**

- Implements a doubly linked list data structure.

- Supports adding and removing items from both ends of the list efficiently.

- Provides forward and backward iterators for traversing the list.

**Usage:**

```lua
  local rlist = require('algo.rlist')

  local list = rlist.new()

  -- Add items to the list
  local item1 = {value = 1}
  list:add_tail(item1)

  local item2 = {value = 2}
  list:add_head(item2)

  -- Remove items from the list
  local was_first = list:remove_first()
  local was_last = list:remove_last()

  -- Traverse the list with custom iterators
  for _, node in list:pairs() do
    process(node)
  end

  for _, node in list:rpairs() do
    process(node)pairs()
  end

  -- rlist always nows how many items it has
  print(rlist.count)
```

Aliased Methods Usage:

```lua
list:push(item) -- Alias for add_tail
list:unshift(item) -- Alias for add_head
local was_first = list:shift() -- Alias for remove_first
local was_last  = list:pop() -- Alias for remove_last
```

## Binary Heap (algo.heap)

Fastest pure-Lua implementation of the binary heap data structure.

Taken as-is from [tarantool/vshard](https://github.com/tarantool/vshard)

**Usage:**

```lua
local heap = require('algo.heap')

-- Create a new heap with a custom comparison function
local my_heap = heap.new(function(a, b) return a.id < b.id end)

-- Push elements onto the heap
my_heap:push({id = 5})
my_heap:push({id = 3})
my_heap:push({id = 7})

-- Get the top element of the heap
local top_element = my_heap:top()

-- Remove the top element from the heap
my_heap:remove_top()

-- Updates position of a specific element in the heap
my_heap:update(element_to_update)

-- Pop and retrieve the top element from the heap
local popped_element = my_heap:pop()

-- Get the current count of elements in the heap
local element_count = my_heap:count()
```

**Functions:**

`push(value):` Add a value to the heap.

`update_top()`: Update the top element position in the heap.

`remove_top()`: Remove the top element from the heap.

`pop()`: Remove and return the top element from the heap.

`update(value)`: Update a specific value in the heap.

`remove(value)`: Remove a specified value from the heap.

`remove_try(value)`: Safely attempt to remove a value if it exists in the heap.

`top()`: Return the top element of the heap.

`count()`: Return the current count of elements in the heap.

## Running Mean (algo.rmean)

The `rmean` module provides functionality for efficient moving average calculations with specified window sizes.

The best use of rmean would be when you want to have Average Calls per second during last 5 seconds.

Easy to set and use:

```lua
local rmean = require 'algo.rmean'

local calls_storage = rmean.collector('rmean_calls_storage', --[[ [window=(default: 5)] ]])

local function call_storage()
   -- increase by one each time, when method is called
   calls_storage:observe(1)
end

calls_storage:per_second() -- => gives Moving Average per Second
calls_storage:max() -- => gives Moving Max within Time Window (default 5 sec)
calls_storage:sum() -- => gives Moving Sum within Time Window (default 5 sec)
calls_storage:mean() -- => gives Moving Mean within Time Window (default 5 sec)
calls_storage:min() -- => gives Moving Min within Time Window (default 5 sec)
calls_storage:hits() -- => gives Moving Count within Time Window (default 5 sec)

-- rmean can be easily connected to metrics:
rmean.default:set_registry(require 'metrics'.registry)
```

Rmean can be used to collect statistics of both discreate and continious variables.

Collect Running Mean (Moving Average) of Latency of your calls:

```lua
local latency_rmean = rmean.collector('latency')

latency_rmean:max() -- Will produce Moving maximum of the latency within specified window
latency_rmean:min() -- Will produce Moving minimum of the latency within specified window
latency_rmean:mean() -- Will produce Moving average of the latency within specified window

-- latency_rmean:per_second() DOES not posses any meaningfull stats

latency_rmean:hits() -- Will produce Moving count of observed values within specified window
```

Collect Per Second statistics for your calls or bytes

```lua
local tuple_size_rmean = rmean.collector('tuple_size')

-- Let's assume you measure bsize of tuples you save into Database
tuple_size_rmean:observe(tuple:bsize())

tuple_size_rmean:per_second() -- will produce Moving average of bytes per second
tuple_size_rmean:max()
tuple_size_rmean:min()
tuple_size_rmean:hits()
```

Read more at [rmean](./doc/rmean.md)

## Ordered Dictionary (algo.odict)

The collection tracks the order in which the items are added and provides
`algo.odict.pairs()` function to get them in this order.

The ordered dictionary is a usual Lua table with a specific metatable. All the
table operations are applicable.

It is similar to Python's [collections.OrderedDict][python-odict].

[python-odict]: https://docs.python.org/3/library/collections.html#collections.OrderedDict

Example:

```lua
local od = odict.new()

od.a = 1
od.b = 2
od.c = 3

print('od.a', od.a) -- 1
print('od.b', od.b) -- 2
print('od.c', od.c) -- 3

for k, v in odict.pairs(od) do
    print(k, v)
end
-- print: a, 1
-- print: b, 2
-- print: c, 3
```

If an element is changed (without prior deletion), it remains on the same
position.

```lua
local od = odict.new()

od.a = 1
od.b = 2
od.c = 3

od.b = 4

for k, v in odict.pairs(od) do
    print(k, v)
end
-- print: a, 1
-- print: b, 4
-- print: c, 3
```

If an element is deleted and added again, it is added to the end.

```lua
local od = odict.new()

od.a = 1
od.b = 2
od.c = 3

od.b = nil
od.b = 4

for k, v in odict.pairs(od) do
    print(k, v)
end
-- print: a, 1
-- print: c, 3
-- print: b, 4
```

Beware: Tarantool's REPL shows the fields as unordered. The same for the
serialization into JSON/YAML/MessagePack formats. It should be solved after
https://github.com/tarantool/tarantool/issues/9747.
