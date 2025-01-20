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

### Usage

For the most convenient use of the `rmean` module, the `default` instance is provided with a window size of 5 seconds, similar to what is used in Tarantool. Here are some examples demonstrating the usage of the `default` rmean instance:

```lua
local rmean = require('algo.rmean')

-- Create a new collector in the default rmean instance with the same window size (5 seconds)
local my_collector = rmean.collector('my_collector')
```

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

#### Observing Values and Calculating Metrics

```lua
-- Observe values for the collector
my_collector:observe(10)
my_collector:observe(15)
my_collector:observe(20)

-- Calculate the moving average per second for the collector
local avg_per_sec = my_collector:per_second()
```

#### Getting All Registered Collectors in the Default rmean Instance

```lua
local all_collectors = rmean.getall()
```

#### Freeing a Specific Collector in the Default rmean Instance

```lua
-- Free a specific collector
-- Collector will become unusable, though it's data will be preserved.
-- This is a true way to destroy collector
rmean.free(my_collector)
```

#### Note

- The `default` rmean instance is the most preferred way to use `rmean`, as it has a window size of 5 seconds, aligning with the common practice in Tarantool.

#### Collector methods

The `rmean` module provides methods to efficiently calculate and access various metrics within the moving average collectors.

##### `sum([depth=window_size])`

- **Usage**: Retrieves the moving sum value within a specified time depth.
- **When to Use**: This method is useful when you need to track the cumulative sum of values observed by the collector over a specific time period.

##### `min([depth=window_size])`

- **Usage**: Returns the moving minimum value within a specified time depth.
- **When to Use**: Use this method when you want to find the minimum value observed by the collector within a specific time window.

##### `max([depth=window_size])`

- **Usage**: Retrieves the moving maximum value within a specified time depth.
- **When to Use**: Utilize this method to determine the maximum value observed by the collector within a particular time frame.

##### `count and total fields`

- **Count Field**: The `count` field represents the monotonic counter of all collected values from the last reset.
- **Total Field**: The `total` field stores the sum of all values collected by the collector from the last reset.
- **When to Use**: You can access these fields to keep track of the total count of observations and the cumulative total sum of values collected by the collector.

```lua
-- Obtain the moving sum value for the last 4 seconds
local sum_last_4_sec = my_collector:sum(4)

-- Get the minimum value observed in the last 3 seconds
local min_last_3_sec = my_collector:min(3)

-- Retrieve the maximum value in the last 2 seconds
local max_last_2_sec = my_collector:max(2)

-- Access the total sum and count fields of the collector
local total_sum = my_collector.total
local observation_count = my_collector.count
```

**Note:** Ensure that the `depth` parameter does not exceed the `window size` of the collector.

### Integrating with tarantool/metrics

```lua
local metrics = require('metrics')
metrics.registry:register(rmean)
```

After registering `rmean` in `tarantool/metrics`, you can seamlessly collect metrics from all registered named rmean collectors.

### Setting Labels for `rmean` Collectors

Each collector within the `rmean` module allows you to set custom labels to provide additional context or categorization for the collected metrics.

```lua
-- Set custom labels for a collector
my_collector:set_labels({ name = 'example_collector', environment = 'production' })
```

Each collector within the `rmean` module provides metrics suitable for export to Prometheus via the `tarantool/metrics` module. The metrics available for export are as follows:

- **rmean_per_second**: Represents the running average of the collected values.
- **rmean_sum**: Represents the running sum of the collected values.
- **rmean_min**: Represents the minimum value observed within the collector's window.
- **rmean_max**: Represents the maximum value observed within the collector's window.
- **rmean_count**: Represents the number of observations made by the collector.
- **rmean_total**: Represents the total sum of all collected values.

### Advanced Usage

1. **Creating a New `rmean` Instance**:

```lua
local rmean = require('algo.rmean')

-- Create a new rmean instance with a specified name, resolution, and window size
local my_rmean = rmean.new('my_rmean_instance', 1, 5)
```

1. **Creating a New Collector**:

   ```lua
   -- Create a new collector within the rmean instance
   local new_collector = my_rmean:collector('my_collector', 5)
   ```

2. **Getting All Collectors**:

   ```lua
   -- Get all registered collectors within the rmean instance
   local all_collectors = my_rmean:getall()
   ```

3. **Getting a Specific Collector**:

   ```lua
   -- Get a specific collector by name
   local specific_collector = my_rmean:get('my_collector')
   ```

4. **Observing Values and Calculating Metrics**:

   ```lua
   -- Observe a value for a collector
   specific_collector:observe(10)

   -- Calculate the moving average per second for a collector
   local avg_per_sec = specific_collector:per_second()
   ```

5. **Reloading a Collector**:

   ```lua
   -- Reload a collector from an existing one
   -- specific_collector will be unsusable after executing this call
   local reloaded_collector = my_rmean:reload(specific_collector)
   ```

6. **Starting and Stopping the System**:

   ```lua
   -- Stop the system and disable creating new collectors
   my_rmean:stop()

   -- Start the system to begin calculating averages
   my_rmean:start()
   ```

7. **Freeing Collectors**:

   ```lua
   -- Free a specific collector
   my_rmean:free(specific_collector)
   ```

8. **Metrics Collection**:

   ```lua
   -- Collect metrics from all registered collectors
   local metrics_data = my_rmean:collect()
   ```

9. **Setting Metrics Registry**:

   ```lua
   -- Set a metrics registry for the rmean instance
   my_rmean:set_registry(metrics_registry)
   ```

### Notes

- The system is automatically started when the rmean instance is created. Manual starting is only required if it was previously stopped.
- The module efficiently handles moving average calculations even with a large number of parallel running collectors and provides high-performance metrics collection capabilities.
