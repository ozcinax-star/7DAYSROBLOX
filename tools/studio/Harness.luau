-- Dev-only Studio harness for the MCP fallback workflow. Never synced into the game.
-- Served by `python -m http.server 8765` next to bundle.json and tests.luau (see bundle.py).
-- Load it from an Edit-mode execute_luau call, without leaving anything in the place:
--
--   local Http = game:GetService("HttpService")
--   local was = Http.HttpEnabled
--   Http.HttpEnabled = true
--   local src = Http:GetAsync("http://127.0.0.1:8765/Harness.luau", true)
--   Http.HttpEnabled = was
--   local H = loadstring(src)()
--   return H.sync() .. "\n" .. H.test(false)
--
-- H.sync()        writes every script of bundle.json into the place (Edit mode only), returns compile errors.
-- H.test(verbose) runs tests.luau against fresh copies of the synced modules, returns failures + summary.
local HttpService = game:GetService("HttpService")

local function fetch(name)
	local was = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, body = pcall(HttpService.GetAsync, HttpService, "http://127.0.0.1:8765/" .. name, true)
	HttpService.HttpEnabled = was
	assert(ok, "fetch failed: " .. tostring(body))
	return body
end

local H = {}

function H.sync()
	local report = {}
	for _, item in HttpService:JSONDecode(fetch("bundle.json")) do
		local parts = string.split(item.path, "/")
		local node = game:GetService(parts[1])
		for i = 2, #parts do
			local child = node:FindFirstChild(parts[i])
			if child == nil then
				child = Instance.new(if i == #parts then item.class else "Folder")
				child.Name = parts[i]
				child.Parent = node
			end
			node = child
		end
		node.Source = item.source
		local fn, err = loadstring(item.source)
		if not fn then
			table.insert(report, item.path .. ": " .. tostring(err))
		end
	end
	return table.concat(report, "\n")
end

-- Loads modules with loadstring + setfenv so every run sees the current Source (Studio caches
-- require results). String requires ("./Noise") resolve relative to the requiring module.
function H.test(verbose)
	local globals = getfenv(0)
	local cache = {}
	local loadModule
	local function resolve(from, path)
		local node = from.Parent
		for _, name in string.split(path, "/") do
			if name == ".." then
				node = node.Parent
			elseif name ~= "." then
				node = node:FindFirstChild(name) or error("missing " .. path)
			end
		end
		return node
	end
	local function requireFrom(from)
		return function(target)
			if type(target) == "string" then
				target = resolve(from, target)
			end
			if cache[target] == nil then
				cache[target] = loadModule(target)
			end
			return cache[target]
		end
	end
	function loadModule(module)
		local fn, err = loadstring(module.Source, module:GetFullName())
		assert(fn, err)
		setfenv(fn, setmetatable({ script = module, require = requireFrom(module) }, { __index = globals }))
		return fn()
	end
	-- tests/run.luau requires "../src/shared/..." and "../src/server/..." like Lune does.
	local roots = {
		["../src/shared/"] = game:GetService("ReplicatedStorage").Shared,
		["../src/server/"] = game:GetService("ServerScriptService").Server,
	}
	local function pathRequire(path)
		for prefix, root in roots do
			if string.sub(path, 1, #prefix) == prefix then
				local node = root
				for _, name in string.split(string.sub(path, #prefix + 1), "/") do
					node = node:FindFirstChild(name) or error("missing " .. path)
				end
				if cache[node] == nil then
					cache[node] = loadModule(node)
				end
				return cache[node]
			end
		end
		error("unmapped " .. path)
	end
	local output = {}
	local fn = loadstring(fetch("tests.luau"), "tests")
	setfenv(fn, setmetatable({
		require = pathRequire,
		print = function(...)
			table.insert(output, table.concat({ ... }, " "))
		end,
	}, { __index = globals }))
	local ok, err = pcall(fn)
	if not ok then
		table.insert(output, "FAIL runner error: " .. tostring(err))
	end
	local lines = {}
	for _, line in output do
		if verbose or string.find(line, "FAIL") or string.find(line, "passed") or string.find(line, "^       ") then
			table.insert(lines, line)
		end
	end
	return table.concat(lines, "\n")
end

-- Exposed so a session can build an Edit-mode preview of the map with fresh sources:
--   H.load(game.ServerScriptService.Server.Services.MapService).init()
-- Afterwards: workspace.Map:Destroy(); workspace.Terrain:Clear(); Players.CharacterAutoLoads = true
function H.load(module)
	local globals = getfenv(0)
	local cache = {}
	local function loadModule(m)
		local fn = assert(loadstring(m.Source, m:GetFullName()))
		local env = setmetatable({ script = m }, { __index = globals })
		env.require = function(target)
			if type(target) == "string" then
				local node = m.Parent
				for _, name in string.split(target, "/") do
					if name == ".." then
						node = node.Parent
					elseif name ~= "." then
						node = node:FindFirstChild(name) or error("missing " .. target)
					end
				end
				target = node
			end
			if cache[target] == nil then
				cache[target] = loadModule(target)
			end
			return cache[target]
		end
		setfenv(fn, env)
		return fn()
	end
	return loadModule(module)
end

return H
