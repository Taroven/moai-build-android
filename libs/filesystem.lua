local lfs = lfs or require("lfs")
local util = util or require("util.util")
local root = lfs.currentdir()
local fs = {}
fs.sep = string.match(lfs.currentdir(),"([/\\])")
fs.os = fs.sep ~= "/" and "windows" or "unix"

local exclude = function (s)
	if s == "." or s == ".." then return true
	elseif string.match(s,"^%.git") or string.match(s,"^%.svn") then return true
	end
end

local handle = function (path, mode)
	return assert(io.open(path,mode))
end

-- Build a clean path out of passed args.
-- Also makes a good attempt at returning an absolute path by using some LFS hax.
fs.path = function (...)
	local t = {...}
	local path = string.gsub(table.concat(t,fs.sep), "[/\\]+", fs.sep)
	path = string.gsub(path,"%[root%]",root)
	local attr = lfs.attributes(path)
	if attr then
		if attr.mode == "directory" then
			_,path = fs.pushd(path)
			fs.popd()
		else
			local up,file = fs.up(path)
			if up then
				_,up = fs.pushd(up)
				fs.popd()
				path = up .. fs.sep .. file
			end
		end
	end
	return path, attr
end

-- Return a string or newline-delimited array of file contents
fs.read = function (path,lines)
		local file,err = handle(path,"r")
		if err then return nil,err; end
		if file and lines then
			local t = {}
			--local s = file:read("*a")
			for line in file:lines() do
				table.insert(t,line)
			end
			file:close()
			return t
		elseif file then
			local s = file:read("*a")
			file:close()
			return s
		end
end

-- Write a string or newline-delimited array to file
fs.write = function (s, path)
	if _TEST then
		print("TEST: util.filesystem.write", path)
		return
	end
	if type(s) == "table" then s = table.concat(s,"\n")
	elseif type(s) ~= "string" then
		return error("util.filesystem: attempt to write non-string/table to file.")
	end
	local file = handle(path,'w+')
	if file then
		file:write(s)
		file:flush()
		file:close()
	end
	return s
end

fs.load = function (path)
	local file = fs.read(path)
	if file then
		return loadstring(file)()
	end
end

-- Return the next directory up from path
fs.up = function (path) return string.match(path, "(.+)[/\\](.+)$") end

-- Since lfs.mkdir is a little clunky for progressive paths, it's better for us to use system commands here.
fs.mkdir = function (...)
	local path = fs.path(...)
	util.exec("mkdir -p", path)
	return path
end
fs.affirm = fs.mkdir

-- Change to directory and return its absolute path if it exists (or current path if it doesn't)
fs.cd = function (...)
	local success = lfs.chdir(fs.path(...))
	return success, lfs.currentdir()
end

-- Unlike pushd/popd in unix, these do not keep a stack.
local ld = {}
fs.pushd = function (path)
	ld[0] = ld[0] or lfs.currentdir()
	local cd = lfs.currentdir()
	local success = lfs.chdir(path)
	if success then
		ld[#ld + 1] = cd
	end
	return success, lfs.currentdir()
end

fs.popd = function ()
	ld[0] = ld[0] or lfs.currentdir()
	local cd = table.remove(ld) or ld[0]
	local success = lfs.chdir(cd)
	return success, lfs.currentdir()
end

local mt = {
	__index = function (self,k)
		return table[k] or chainsaw[k]
	end
}
fs.ls = function (path,recurse,list)
	local paths = table.affirm(path)
	if #paths == 0 then paths[1] = lfs.currentdir() end
	local list = list or {}
	
	for i,v in ipairs(paths) do
		local attr = lfs.attributes(v)
		local apath
		if v and v.mode == "directory" then -- passed an existing directory, get its absolute path
			_,apath = fs.pushd(v)
			fs.popd()
		elseif v then -- passed an existing file, get its parent directory
			apath = fs.up(v)
		end
		
		if apath then
			for file in lfs.dir(v) do
				if not exclude(file) then
					local fp,attr = fs.path(v,file)
					if type(recurse) == "boolean" and not recurse then
						if attr.mode ~= "directory" then
							list[#list + 1] = fp
						end
					elseif recurse and attr.mode == "directory" then
						list = fs.ls(fp,recurse,list)
					else
						list[#list + 1] = fp
					end
				end
			end
		end
	end
	
	setmetatable(list, mt) -- util adds directly to table, so we can get away with this.
	return list
end

-- Where ls produces an array, tree gives a paired table.
-- tostring(tree[k]) will ALWAYS produce an absolute path.
fs.tree = function (path)
	local path, attr = fs.path(path)
	if attr and attr.mode ~= "directory" then path = fs.up(path) end
	if not path and attr then return end
	
	local list = {}
	for file in lfs.dir(path) do
		if not exclude(file) then
			local fp, fa = fs.path(path, file)
			if fa.mode == "directory" then
				list[file] = fs.tree(fp)
			else
				list[file] = fp
			end
		end
	end
	
	return setmetatable(list,{fp = path, __tostring = function (self) return getmetatable(self).fp end})
end

return fs