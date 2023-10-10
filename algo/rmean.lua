local clock = require 'clock'
local fiber = require 'fiber'
local ffi = require "ffi"
local rlist = require 'algo.rlist'

local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local setmetatable = setmetatable
local table_new = table.new
local tonumber = tonumber
local type = type

---Appends all k-vs from t2 to t1, if not exists in t1
---@param t1 table?
---@param t2 table?
local function merge(t1, t2)
	if type(t1) ~= 'table' or type(t2) ~= 'table' then return end

	for k in pairs(t2) do
		if t1[k] == nil then
			t1[k] = t2[k]
		end
	end
end

---Class rmean is plain-Lua implementation of Tarantool's rmean collector
---
---rmean provides window function mean with specified window size (default=5s)
---rmean well tested on 10K parallel running collectors
---
---rmean:collect(value) is lightning fast ≈ 1B calls per second with jit.on
---and ≈ 15M with jit.off
---
---rmean:mean() makes 10M calls per second with jit.off() and ≈50M calls with jit.on
---
---rmean creates sigle fiber for all collectors which rerolls timings
---it takes 4µs per created counter.
---@class algo.rmean
---@field window integer default window size of rmean.collector
---@field _resolution number default resolution of rmean (in seconds)
---@field roller_tm algo.rmean.collector
---@field _prev_ts number last timestamp
---@field _running boolean
---@field _collectors algo.rlist
---@field _registry table<string,algo.rmean.collector.weak>
---@field _roller_f? Fiber

---@class algo.rmean.collector.weak:algo.rlist.item
---@field collector algo.rmean.collector weakref to collector

---rmean.collector is named separate counter
---@class algo.rmean.collector
---@field name string? name of collector
---@field window number window size of collector (default=5s)
---@field size number capacity collector (window/resolution)
---@field label_pairs table<string,string> specified label pairs for metrics
---@field sum_value number[] list of sum values per second
---@field min_value number[] list of min values per second
---@field max_value number[] list of max values per second
---@field total number sum of all values from last reset
---@field count number monotonic counter of all collected values from last reset
---@field _resolution number length in seconds of each slot
---@field _rlist_item algo.rmean.collector.weak weakref to link inside rlist
---@field _gc_hook ffi.cdata* gc-hook to track collector was gc-ed
local collector = {}

local map_mt  = { __serialize = 'map' }
local list_mt = { __serialize = 'seq' }
local weak_mt = { __mode = 'v' }

local collector_mt = {
	__index = collector,
	__tostring = function(self)
		local min, max = self:min(), self:max()
		return ("rmean<%s:%ds> [per_sec:%.2f/sum:%.2f/cnt:%d/min:%s/max:%s]"):format(
			self.name or 'anon', self.window,
			self:per_second(),
			self.total,
			self.count,
			min and ("%.2f"):format(min) or "null",
			max and ("%.2f"):format(max) or "null"
		)
	end,
	__serialize = function(self)
		return setmetatable({
			name = self.name,
			total = self.total,
			count = self.count,
			window = self.window,
			min = self:min(),
			max = self:max(),
			per_second = self:per_second(),
		}, map_mt)
	end
}

--#region algo.rmean.utils

---Creates new list with null values
---@param size number
---@private
---@return number[]
local function new_list(size)
	size = math_floor(size)
	local t = setmetatable(table_new(size, 0), list_mt)
	return t
end

---Creates new list with zero values
---@param size number
---@private
---@return number[]
local function new_zero_list(size)
	local t = new_list(size)
	-- we start iteration from 0
	-- we abuse how lua stores arrays
	for i = 0, size do
		t[i] = 0
	end
	return t
end

---@param depth number
---@param max_value number
---@return integer
local function _get_depth(depth, max_value)
	depth = tonumber(depth)
	if depth then
		depth = math_floor(depth)
		if depth > max_value then
			depth = max_value
		end
		if depth <= 0 then
			return 0
		end
	else
		depth = max_value
	end
	return depth
end

local function _list_serialize(list)
	local r = {}
	for i = 1, #list do
		r[i] = tostring(list[i])
	end
	return r
end

--#endregion

---fiber roller of registered collectors
---@private
---@param self algo.rmean
local function rmean_roller_f(self)
	fiber.self():set_joinable(true)
	self._roller_f = fiber.self()
	fiber.name("rmean/roller_f")
	self._prev_ts = clock.time()
	if not self.roller_tm then
		self.roller_tm = self:collector("roller_time")
		self.roller_tm:set_labels({
			name = 'roller_time',
			window = self.roller_tm.window,
			unit = 'mks',
		})
	end

	while self._running do
		fiber.sleep(self._resolution)
		if not self._running then break end
		if not pcall(fiber.testcancel) then break end

		local nownano = clock.time64()

		local prev_ts, now = self._prev_ts, tonumber(nownano) / 1e9
		local dt = now - prev_ts

		local s = nownano

		local i = 0
		for _, cursor in self._collectors:pairs() do
			---@cast cursor algo.rmean.collector.weak
			i = i + 1
			if i % 100 == 0 then
				fiber.yield()
				if not pcall(fiber.testcancel) then break end
				now = clock.time()
				dt = now-prev_ts
			end
			if cursor.collector then
				cursor.collector:roll(dt)
			end
		end

		nownano = clock.time64()
		now = tonumber(nownano)/1e9
		self._prev_ts = now
		self.roller_tm:observe((nownano-s)/1e3)
	end
	-- be nice and remove self-collector
	if self.roller_tm then
		self:free(self.roller_tm)
		self.roller_tm._gc_hook = nil
	end
end

---@class algo.rmean
local rmean_methods = {}

---Creates new rmean collector
---@param name string?
---@param window integer? default=5 seconds
---@return algo.rmean.collector
function rmean_methods:collector(name, window)
	if name == self then
		error("Usage: rmean.new([name],[window]) (not rmean:new())", 2)
	end
	if not self._running then
		error("Attempt to create collector on stopped rmean", 2)
	end

	if not name then
		name = 'anon'
	end

	window = tonumber(window) or self.window
	local size = math_floor(window/self._resolution)
	local remote = setmetatable({
		name = name,
		window = window,
		size = size,
		sum_value = new_zero_list(size),
		min_value = new_list(size),
		max_value = new_list(size),
		label_pairs = { name = name, window = window },
		total = 0,
		count = 0,
		__version = 1,
		_resolution = self._resolution,
	}, collector_mt)

	---@type algo.rmean.collector.weak
	local _item = setmetatable({ collector = remote }, weak_mt)
	remote._rlist_item = _item

	self._registry[name] = _item
	self._collectors:push(_item)

	remote._gc_hook = ffi.gc(ffi.new('char[1]'), function()
		pcall(self._collectors.remove, self._collectors, _item)
		if self._registry[name] == _item then
			self._registry[name] = nil
		end
	end)

	return remote
end

---Creates new counter from given one
---@param counter algo.rmean.collector
---@return algo.rmean.collector
function rmean_methods:reload(counter)
	-- ? check __version
	local new = self:collector(counter.name)
	new.sum_value = counter.sum_value
	new.count = counter.count
	new.total = counter.total
	new.max_value = counter.max_value
	new.min_value = counter.min_value
	return new
end

function rmean_methods:start()
	self._running = true
	if not self._roller_f then
		fiber.create(rmean_roller_f, self)
	end
end

---Stops fiber and disables creating of new counters
function rmean_methods:stop()
	self._running = false
	self._roller_f:cancel()
	self:free(self.roller_tm)
	self.roller_tm = nil
end

---returns list of all registered collectors
---@return algo.rmean.collector[]
function rmean_methods:getall()
	local rv = table_new(self._collectors.count, 0)
	local n = 0

	setmetatable(rv, {__serialize = _list_serialize})

	for _, cursor in self._collectors:pairs() do
		---@cast cursor algo.rmean.collector.weak
		local t = cursor.collector
		if t then
			n = n + 1
			rv[n] = t
		end
	end
	return rv
end

---returns registered collector by name
---@param name string
---@return algo.rmean.collector?
function rmean_methods:get(name)
	if not name then
		return self:getall()
	end
	local weak = self._registry[name]
	if not weak then
		return
	end
	return weak.collector
end

---frees collector
---@param counter algo.rmean.collector
function rmean_methods:free(counter)
	if counter._rlist_item == nil then return end
	self._collectors:remove(counter._rlist_item)
	counter._rlist_item = nil
end

---metrics collect hook
function rmean_methods:collect()
	local result = table.new(self._collectors.count*6, 0)
	local label_pairs
	if self.metrics_registry then
		label_pairs = self.metrics_registry.label_pairs
	end
	for _, item in self._collectors:pairs() do
		---@cast item algo.rmean.collector.weak
		local clt = item.collector
		if clt and clt.name ~= 'anon' then
			for _, obs in ipairs(clt:collect()) do
				merge(obs.label_pairs, label_pairs)
				table.insert(result, obs)
			end
		end
	end
	return result
end

---metrics set_registry hook
---@param metrics_registry any
function rmean_methods:set_registry(metrics_registry)
	self.metrics_registry = metrics_registry
end

--#region algo.rmean.collector

---Calculates and returns per_second value
---@param depth integer? depth in seconds (default=window size, [1,window size])
---@return number
function collector:per_second(depth)
	depth = _get_depth(depth, self.window)
	local sum = 0
	for i = 1, depth/self._resolution do
		sum = sum + self.sum_value[i]
	end
	return sum / depth
end

function collector:set_labels(label_pairs)
	self.label_pairs = table.copy(label_pairs)
end

---Returns moving min value
---@param depth integer? depth in seconds (default=window size, [1,window size])
---@return number? min # can return null if no values were observed
function collector:min(depth)
	depth = _get_depth(depth, self.window)

	local min
	for i = 1, depth/self._resolution do
		if not min or (self.min_value[i] and min > self.min_value[i]) then
			min = self.min_value[i]
		end
	end
	return min
end

---Returns moving max value
---@param depth integer? depth in seconds (default=window size, [1,window size])
---@return number? max # can return null if no values were observed
function collector:max(depth)
	depth = _get_depth(depth, self.window)

	local max
	for i = 1, depth/self._resolution do
		if not max or (self.max_value[i] and max < self.max_value[i]) then
			max = self.max_value[i]
		end
	end
	return max
end

---Returns moving sum value
---@param depth integer? depth in seconds (default=window size, [1,window size])
---@return number? sum # can return null if no values were observed
function collector:sum(depth)
	depth = _get_depth(depth, self.window)

	local sum = 0
	for i = 1, depth/self._resolution do
		sum = sum + self.sum_value[i]
	end
	return sum
end

---Increments current time bucket with given value
---@param value number|uint64_t|integer64
function collector:observe(value)
	value = tonumber(value)
	if not value then return end

	self.sum_value[0] = self.sum_value[0] + value
	self.total = self.total + value
	self.count = self.count + 1

	self.min_value[0] = math_min(self.min_value[0] or value, value)
	self.max_value[0] = math_max(self.max_value[0] or value, value)
end

-- just alias
collector.inc = collector.observe

function collector:collect()
	return {
		{
			metric_name = 'rmean_per_second',
			value = self:per_second(),
			label_pairs = self.label_pairs,
			timestamp = fiber.time64(),
		},
		{ metric_name = 'rmean_sum',   value = self:sum(),  label_pairs = self.label_pairs,  timestamp = fiber.time64() },
		{ metric_name = 'rmean_min',   value = self:min(),  label_pairs = self.label_pairs,  timestamp = fiber.time64() },
		{ metric_name = 'rmean_max',   value = self:max(),  label_pairs = self.label_pairs,  timestamp = fiber.time64() },
		{ metric_name = 'rmean_total', value = self.total,  label_pairs = self.label_pairs,  timestamp = fiber.time64() },
		{ metric_name = 'rmean_count', value = self.count,  label_pairs = self.label_pairs,  timestamp = fiber.time64() },
	}
end

---Rerolls statistics
---@param dt number
function collector:roll(dt)
	if dt < 0 then return end
	local sum = self.sum_value
	local min = self.min_value
	local max = self.max_value
	local avg = sum[0] / dt
	local j = math_floor(self.size)
	while j > dt+0.1 do
		if j > 0 then
			sum[j], min[j], max[j] = sum[j-1], min[j-1], max[j-1]
		else
			sum[j] = avg
		end
		j = j - 1
	end
	for i = j, 1, -1 do
		sum[i], min[i], max[i] = avg, min[0], max[0]
	end
	sum[0] = 0
	min[0] = nil
	max[0] = nil
end

---Resets all collected values to zero
function collector:reset()
	for i = 0, self.size do
		self.sum_value[i] = 0
	end
	table.clear(self.min_value)
	table.clear(self.max_value)
	self.total = 0
	self.count = 0
end

--#endregion

local rmean_mt = {
	__index = rmean_methods,
	__serialize = function(self)
		return {
			window = self.window,
			roller_tm = self.roller_tm,
			collectors = self._collectors,
			resolution = self._resolution,
		}
	end,
}

---Creates new rmean
---@param name string name of the new rmean
---@param resolution number time resolution
---@param window number default time window
---@return algo.rmean
local function new(name, resolution, window)
	local rmean = setmetatable({
		kind = 'gauge',
		help = 'rmean collector',
		name = name,
		window = window,
		_resolution = resolution,
		_collectors = rlist.new(),
		_registry = setmetatable({}, weak_mt),
	}, rmean_mt)

	rmean:start()
	return rmean
end

---Defaults
local RESOLUTION = 1
local WINDOW_SIZE = 5

local default = new('default', RESOLUTION, WINDOW_SIZE)

return {
	new = new,
	default   = default,
	collector = function(_,...) return default:collector(...) end,
	reload    = function(_,...) return default:reload(...) end,
	stop      = function()    return default:stop() end,
	getall    = function()    return default:getall() end,
	get       = function(_,...) return default:get(...) end,
	free      = function(_,...) return default:free(...) end,
}
