local type,tonumber = type,tonumber

local escapes = {
	["^"] = "%^",
	["$"] = "%$",
	["("] = "%(",
	[")"] = "%)",
	["%"] = "%%",
	["."] = "%.",
	["["] = "%[",
	["]"] = "%]",
	["*"] = "%*",
	["+"] = "%+",
	["-"] = "%-",
	["?"] = "%?",
	["\0"] = "%z",
}

local util = {}

-- Macro for os.execute
util.exec = function (...)
	return os.execute(table.concat({...}," "))
end
-- We don't expect config to be perfect, so this provides a sensible default while also converting bool to 0/1
util.bool = function (c,default)
	if type(c) == "boolean" then return (c and 1 or 0)
	else return default end
end

-- Newline-separated print, then prompt for input. Enter to continue, Q to quit, otherwise returns input.
util.prompt = function (...)
	local s = {...}
	for i,v in ipairs(s) do print(v) end
	if not util.skip then
		print("Press enter to continue, or Q (enter) to quit.")
		local r = io.read()
		if r and string.match(r,"^[qQ]") then
			print("Quitting.")
			return os.exit()
		else return r
		end
	end
end

-- table helpers
local t = {}
local s = {}
util.table = t
util.string = s

-- split string by delimiter
s.explode = function (s,sep)
	local t = {}
	for w in string.gmatch(s,sep) do
		t[#t + 1] = w
	end
	return unpack(t)
end

-- Escape magic chars when pattern matching
s.escape = function(s) return (string.gsub(s, ".", escapes)) end

-- ensure that a passed value is a workable table or other accepted type
t.affirm = function (self,paired,accepted)
	if type(self) == "string" then return (type(paired) == "boolean" and {[self] = paired} or {self})
	elseif type(self) == "table" then
		if type(paired) == "boolean" then
			local r = {}
			for k,v in pairs(self) do
				local x = tonumber(k) and v or k
				local y = not(tonumber(k)) and v or paired
				r[x] = y
			end
			return r
		end
		return self
	elseif type(self) == accepted then return self end
end

-- default filter used by t.filter
local df = function (k,v,filter)
	for x,y in pairs(filter) do
		local match = string.match(v,(tonumber(x) and y or x)) -- match depending on {pattern=qualifier} or {pattern,...}
		if y and match then return k,v end
	end
end

-- trim table according to pattern matches, preserving metatables (makes for really cool call chains)
t.filter = function (self,filter)
	local src = t.affirm(self)
	local filter = t.affirm(filter,nil,"function")
	if src then
		local f = type(filter) == "table" and df or type(filter) == "function" and filter
		if type(f) == "function" then -- make sure we're not passing something really strange as a filter
			local dest = {}
			for k,v in pairs(src) do
				local x,y = f(k,v,filter)
				if x and y then
					x = tonumber(x) and (#dest + 1) or x
					dest[x] = y
				end
			end
			if getmetatable(src) then setmetatable(dest,getmetatable(src)) end
			return dest
		else return src end --...but if we are, return *something*.
	end
end

-- translate array entries according to dictionary
t.translate = function (self,dict)
	local s,d = t.affirm(self), t.affirm(dict)
	if s and d then
		local dest = {}
		for k,v in pairs(s) do dest[k] = d[v] or v end
		return dest
	end
end

-- Combine a set of tables. Dominance is by arg #, so pass defaults before preferred entries.
-- Pass true as the first or last arg if you need recursion. Otherwise, tables are treated like any other value and will be overridden.
t.merge = function (...)
	local src = {...}
	local recurse
	if src[1] == true then
		recurse = true
		table.remove(src,1)
	elseif src[#src] == true then
		recurse = true
		table.remove(src)
	end
	
	local dest = {}
	for i,entry in ipairs(src) do
		if type(entry) ~= "table" then dest[#dest + 1] = entry
		else
			for k,v in pairs(entry) do
				if recurse and (not tonumber(k)) and (type(v) == "table") and (type(dest[k]) == "table") then
					dest[k] = t.merge(dest[k],v)
				elseif tonumber(k) then dest[#dest + 1] = v
				else dest[k] = v
				end
			end
		end
	end
	return dest
end

-- remove matching values from self (array only, not in-place)
t.exclude = function (self,t)
	local dest = {}
	for i,v in ipairs(self) do dest[i] = v end
	for _,v in ipairs(t) do
		local i = 1
		while true do
			if v == x then table.remove(dest,i)
			else i = i + 1
			end
		end
	end
	return dest
end

-- remove duplicates from self (array only, in-place, will iterate at least twice to snag all possible dupes)
t.unique = function (self)
	while true do
		local found
		for i,v in ipairs(self) do
			for x,y in ipairs(self) do
				if (i ~= x) and v == y then
					table.remove(self,x)
					found = true
				end
			end
		end
		if not found then break end
	end
	return self
end

for k,v in pairs(t) do table[k] = v end
for k,v in pairs(s) do string[k] = v end

return util