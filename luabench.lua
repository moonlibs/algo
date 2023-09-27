local fio = require 'fio'
local log = require 'log'
local clock = require 'clock'
local misc = require 'misc'

---@param root string
---@param recurse string[]
local function traverse(root, recurse)
	local list = assert(fio.listdir(root))
	for _, item in ipairs(list) do
		local full_path = fio.pathjoin(root, item)
		-- you won't have problems if you just skip symlinks ;)
		if not fio.readlink(full_path) then
			if fio.path.is_dir(full_path) then
				traverse(full_path, recurse)
			elseif fio.path.is_file(full_path) then
				table.insert(recurse, full_path)
			-- otherwise just skip
			end
		end
	end
end

---@class luabench.benchmark_file
---@field module table<string,fun(any)>
---@field funcs string[]
---@field file string

---requires benchmark file
---@param file string
---@return luabench.benchmark_file
local function load_benchmark_file(file)
	local env = setmetatable({}, {__index=_G})
	local loader, err = loadfile(file, "bt", env)
	if loader == nil then
		log.error("During parsing file %s: %s", file, err)
		os.exit(1)
	end

	local ok, module = pcall(loader, file)
	if not ok then
		log.error("During loading file %s: %s", file, module)
		os.exit(1)
	end

	-- now we traverse module-table to find 'bench_' function
	if type(module) ~= 'table' then
		log.error('Benchmark file expected to return "table", received %q (file: %q)',
			type(module), file)
		os.exit(1)
	end

	local funcs = {}
	local max_name_size = 0
	for name, func in pairs(module) do
		if type(name) == 'string' and name:startswith('bench_') then
			if type(func) == 'function' then
				table.insert(funcs, name)
				if max_name_size < #name then
					max_name_size = #name
				end
			end
		end
	end

	if #funcs == 0 then
		log.warn("Benchmark file has no bench_XXX functions (file: %q)", file)
	end

	table.sort(funcs)

	return {
		file = file,
		module = module,
		funcs = funcs,
		max_name_size = max_name_size,
	}
end

local function clear_memory()
	local cycles = 0
	local mem2
	repeat
		local mem1 = collectgarbage("count")
		collectgarbage('collect')
		mem2 = collectgarbage("count")
		cycles = cycles + 1
	until mem2 > 0.75*mem1
end

local function gcbytes()
	return collectgarbage('count')*1024
end

---@param func fun()
---@return fun()
local function wrap(func)
	local function tail(ok, ...)
		if not ok then
			log.error(...)
			error(...)
		else
			return ...
		end
	end
	return function(...)
		return tail(xpcall(func, debug.traceback, ...))
	end
end

---@class luabench.benchmark.report
---@field iters integer
---@field start integer64
---@field start_proc_cpu integer64
---@field start_thread_cpu integer64
---@field start_mem number
---@field finish integer64
---@field finish_proc_cpu integer64
---@field finish_thread_cpu integer64
---@field finish_mem number
---@field last_mem number

---@param bench_file luabench.benchmark_file
---@param func_name string
---@param opts table benchmark options
---@return luabench.benchmark.report
local function run_benchmark(bench_file, func_name, opts)
	-- it must not disappear
	local func = wrap(assert(bench_file.module[func_name]))
	local duration = opts.duration

	local bench_name = (bench_file.file .. '_' .. func_name):gsub("/", "_")
	local run_memprof = opts.run_memprof
	local run_sysprof = opts.run_sysprof

	-- benchmark context
	-- we need this clock only to determine duration of entire benchmark

	if duration.iters then
		-- static benchmark
		local function loop(N, f, b)
			f(b)
		end

		-- warm-up
		clear_memory()
		if opts.warmup then
			loop(1e3, func)
		end

		clear_memory()
		if run_memprof then
			local name = 'memprof_'..bench_name..'.bin'
			print("Starting", name)
			assert(misc.memprof.start(name))
		end
		if run_sysprof then
			local name = 'sysprof_'..bench_name..'.bin'
			print("Starting", name)
			assert(misc.sysprof.start({
				mode = 'C',
				interval = 10,
				path = name,
			}))
		end

		local b = {
			N = tonumber(duration.iters), -- can be nil
			start = clock.monotonic64(),
			start_thread_cpu = clock.thread64(),
			start_proc_cpu = clock.proc64(),
			-- luagc
			start_mem = gcbytes(),
		}

		loop(b.N, func, b)
		local fin, fin_thread_cpu, fin_proc_cpu = clock.monotonic64(), clock.thread64(), clock.proc64()
		local finish_mem = gcbytes()

		if run_memprof then
			assert(misc.memprof.stop())
		end
		if run_sysprof then
			assert(misc.sysprof.stop())
		end

		clear_memory()
		local last_mem = gcbytes()

		b.finish = fin
		b.finish_thread_cpu = fin_thread_cpu
		b.finish_proc_cpu = fin_proc_cpu
		b.finish_mem = finish_mem
		b.last_mem = last_mem
		b.iters = b.N

		return b
	else
		local seconds = assert(duration.seconds)

		-- now we need time-aware loop
		local function loop(time64, dead, f)
			local n = 1
			local total = 0
			local b = { N = n }
			local prev, now = time64(), time64()
			repeat
				f(b)
				total = total+n
				now, prev = time64(), now
				if prev + 1e6 > now then -- ≤1ms
					n = n * 2
					b.N = n
				end
			until dead < now
			return total
		end

		clear_memory()

		if run_memprof then
			local name = 'memprof_'..bench_name..'.bin'
			print("Starting", name)
			assert(misc.memprof.start(name))
		end
		if run_sysprof then
			local name = 'sysprof_'..bench_name..'.bin'
			print("Starting", name)
			assert(misc.sysprof.start({
				mode = 'C',
				interval = 10,
				path = name,
			}))
		end

		local start = clock.monotonic64()
		local deadline = start+seconds*1e9

		local b = {
			start = start,
			deadline = deadline,

			start_thread_cpu = clock.thread64(),
			start_proc_cpu = clock.proc64(),
			-- luagc
			start_mem = gcbytes(),
		}
		local iters = loop(clock.monotonic64, deadline, func)

		local fin, fin_thread_cpu, fin_proc_cpu = clock.monotonic64(), clock.thread64(), clock.proc64()
		local finish_mem = gcbytes()

		if run_memprof then
			assert(misc.memprof.stop())
		end
		if run_sysprof then
			assert(misc.sysprof.stop())
		end

		clear_memory()
		local last_mem = gcbytes()

		b.finish = fin
		b.finish_thread_cpu = fin_thread_cpu
		b.finish_proc_cpu = fin_proc_cpu
		b.finish_mem = finish_mem
		b.last_mem = last_mem
		b.iters = iters

		return b
	end
end

---@param bytes number
---@return string
local function tomem(bytes)
	local sign = bytes > 0 and "+" or ""
	if bytes > 2^20 then
		return ("%s%.2fMB"):format(sign, bytes / 2^20)
	elseif bytes > 2^10 then
		return ("%s%.2fKB"):format(sign, bytes / 2^20)
	else
		return ("%s%dB"):format(sign, bytes)
	end
end

---Runs benchmark from cli
---@param args table
local function run(args)
	local path = args.path
	assert(type(path) == 'string')

	---@type string[]
	local recurse = {}
	if not fio.path.exists(path) then
		log.error("Path %s does not exists", path)
		os.exit(1)
	elseif fio.path.is_file(path) then
		recurse[1] = path
	elseif fio.path.is_dir(path) then
		-- do traverse
		traverse(path, recurse)
	else
		log.error("Given path %s is not a file nor directory", path)
		os.exit(1)
	end

	-- now filter files with suffix '_bench.lua'
	local files = {}
	for _, file in ipairs(recurse) do
		if file:endswith('_bench.lua') then
			table.insert(files, file)
			local _, err = fio.stat(file)
			if err ~= nil then
				log.error(err)
				os.exit(1)
			end
		end
	end

	-- Performing init/load phase (it might fail)
	local max_name_size = 0
	local benchmarks = {}
	for _, file in ipairs(files) do
		benchmarks[file] = load_benchmark_file(file)
		local mns = benchmarks[file].max_name_size
		if max_name_size < mns then
			max_name_size = mns
		end
	end

	table.sort(files)

	-- now we start benchmarking, file by file
	-- for each benchmark-function we must create benchmark-context
	-- but only before execution

	for _, file in ipairs(files) do
		local bench_file = benchmarks[file]

		for _, func_name in ipairs(bench_file.funcs) do
			--? maybe we should create benchmark context here
			local report = run_benchmark(bench_file, func_name, args)

			if args.run_sysprof then
				local sysprof = misc.sysprof.report()
				log.info(sysprof)
			end

			-- log.info(report)
			print(("%-"..max_name_size.."s".."\t%s\t%s ns/op\t%.2f op/s (proc: %.2fs, thread: %.2fs) (mem: %s / %s)"):format(
				func_name, report.iters,
				tonumber((report.finish - report.start) / report.iters),
				tonumber(report.iters) / (tonumber(report.finish - report.start)/1e9),
				tonumber(report.finish_proc_cpu - report.start_proc_cpu)/1e9,
				tonumber(report.finish_thread_cpu - report.start_thread_cpu)/1e9,
				tomem(report.finish_mem - report.start_mem),
				tomem(report.last_mem - report.start_mem)
			))
		end
	end

	-- log.info(reports)
	return true
end

local mod_name = ...
if not mod_name or not mod_name:endswith("luabench") then
	local parser = require 'argparse'()
		:name "luabench"
		:description "Runs lua code benchmarks"
		:add_help(true)

	parser:flag "-v" "--verbose"
		:target "verbose"
		:description "Increase verbosity"

	parser:argument "path"
		:target "path"
		:args "1"
		:description "Run benchmark from specified paths"

	parser:flag "--memprof"
		:target "run_memprof"
		:description "run memory profile"

	parser:flag "--sysprof"
		:target "run_sysprof"
		:description "run cpu profile"

	parser:option "-d" "--duration"
		:target "duration"
		:convert(function(x)
			local orig = x
			local iters = x:match('^([0-9]+)x$')
			if iters then
				return { iters = iters }
			end

			local seconds = x:match('^([0-9]+)s$')
			if not seconds then
				return nil, ("Malformed duration given %s"):format(orig)
			end

			return { seconds = tonumber(seconds) }
		end)
		:default({ seconds = 3 })
		:description "test duration limit"

	local args = parser:parse()
	os.exit(run(args))
end

--- Here goes module luabench itself
