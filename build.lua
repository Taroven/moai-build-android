local cli = require "cliargs"
require("util.init")
local root = lfs.currentdir()

config, dirs, files = {},{},{}

-- Little note: fs.path has two returns, so calls surounded by parenthesis are required in some cases to catch only the first (the path)
local external = { -- I wonder where Play Store verification is?
	"adcolony", -- Ads.
	"chartboost", -- Analytics
	"crittercism", -- Crash analytics
	"facebook", -- Facebook API
	"google-billing", -- IAP support
	--"google-billingv3", -- Different IAP API. It's not included in the build scripts and does not seem complete. Use with caution. Note that this is not a harmless include, it overwrites MoaiGoogleBilling.java.
	"google-play-services", -- Google Play Games support (achievements, etc)
	"google-push", -- Google C2DM/GCM support
	"miscellaneous", -- Base64 support (apparently required for Google billing)
	"tapjoy", -- Banner and video ads
	"twitter", -- Twitter API
}
local libs = table.affirm(external, false)

local subout = { -- map directories to source flags if needed
	["google-play-services"] = "playservices",
	["google-billing"] = "billing",
	["google-push"] = "notifications",
}
local disabled = {}
local buildcmd

local components = {
	untz = true,
	fmod = false,
	luajit = true,
	box2d = true,
	chipmunk = false,
	curl = true,
	crypto = true,
	expat = true,
	freetype = true,
	http_client = true,
	json = true,
	jpg = true,
	luaext = true,
	mongoose = true,
	ogg = true,
	openssl = true,
	sqlite3 = true,
	tinyxml = true,
	png = true,
	sfmt = true,
	vorbis = true,
}

-- Tagging func for apk names
local stamp = function (cfg)
	local apkname = cfg.apkname
	while true do
		local m = string.match(apkname,"(%b[])")
		if m then
			local ce = string.match(m,"%[(.-)%]")
			local c = tostring(cfg[ce])
			if ce == "timestamp" then
				c = os.date(c)
			end
			apkname = string.gsub(apkname,string.escape(m),c)
		else break end
	end
	if not string.match(apkname,"%.apk$") then apkname = apkname .. ".apk"; end
	return apkname
end

local link = function (src,dest)
	local src,dest = src,dest
	if type(src) == "string" then
		src = {src}
	end
	for i,v in pairs(src) do
		local attr = lfs.attributes(v)
		local copycmd = (config.symlink and "ln -s" or "cp -fR")
		if attr then
			util.exec(copycmd,v,dest)
		else
			print("Attempt to copy/link " .. v .. " failed; file does not exist.")
		end
	end
end

local res = {
	"drawable-ldpi", "drawable-mdpi", "drawable-hdpi", "drawable-xxhdpi", --"drawable-xxxhdpi", -- need xxxhdpi resources for that.
	"raw", "values",
}

-- Confirm that necessary resources are in the expected res directory before building the apk.
-- This also builds a sensible res directory structure.
local checkresources = function ()
	for i,v in ipairs(res) do
		util.exec("mkdir -p",(fs.path(dirs.source.res,v)))
	end
	local dir = fs.tree(dirs.source.res)
	for k,v in pairs(dir) do
		if type(v) == "table" and string.match(k,"drawable%-") then
			if not v["icon.png"] then
				local dpi = string.match(k,"drawable%-(%w+)")
				local src = fs.path(dirs.source.hostsource, "d.res", "icon-" .. dpi .. ".png")
				print(src)
				if lfs.attributes(src) then
					local dest = fs.path(tostring(v),"icon.png")
					util.exec("cp -f",src,dest)
				end
			end
		end
	end
end

-- Snag and load the config file, merge global and package config, and apply defaults.
local loadconfig = function (args)
	local cpath = fs.path(args.config)
	local c = fs.load((fs.path(cpath,"global.lua")))
	if c then
		local p = c[args.project]
		if type(p) == "table" then
			c = table.merge(c,p)
		elseif type(p) ~= "nil" then
			print("Specified project (" .. args.project .. ") has an entry in " .. args.config .. ", but is not a table.")
		end
		
		local p = fs.path(cpath,args.project .. ".lua")
		if lfs.attributes(p) then
			print("Loading config file " .. p)
			local s = fs.load(p)
			c = table.merge(c,s)
		end
	else
		print("Could not load " .. args.config)
		print(err)
		return os.exit(1,true)
	end
	
	return c
end

local init = function ()
	cli:set_name("lua build.lua")
	cli:add_arg("project","Project name to build","test")
	cli:optarg("config","Path to config directory","[root]/config")
	cli:add_flag("--clean","Force fresh native builds (use if you've updated your repo)")
	cli:add_flag("--test","No file ops (same as config.noop)")
	cli:add_flag("--skip","No confirmation pauses (same as config.skip)")
	cli:add_flag("--export","Export an APK once build is complete (uses SDK and Ant)")
	cli:add_flag("--debug","Override config.buildtype as Debug")
	cli:add_flag("--release","Override config.buildtype as Release")
	cli:add_opt("--phase=#","Start at phase # (useful for testing)","1")
	local args = cli:parse()
	config = loadconfig(args)
	local c = config
	c.project = args.project
	c.clean = c.clean or args.clean
	c.noop = c.noop or args.test
	c.skip = c.skip or args.skip
	c.export = c.export or args.export
	c.buildtype = args.debug and "Debug" or args.release and "Release" or c.buildtype or "Debug"
	c.timestamp = c.timestamp and string.gsub(c.timestamp,"[/\\]","-") or "%d%m%y_%H%M"
	c.untz = util.bool(c.untz,1)
	c.fmod = util.bool(c.fmod,0)
	c.jit = util.bool(c.jit,1)
	c.box2d = util.bool(c.box2d,1)
	c.chipmunk = util.bool(c.chipmunk,0)
	c.buildtype = type(c.buildtype) == "string" and c.buildtype or "Debug"
	c.run = type(c.run) == "table" and c.run or type(c.run) == "string" and {c.run} or {"main.lua"}
	c.platform = c.platform and tostring(c.platform) or "android-10"
	c.apkname = stamp(c)
	
	util.skip = c.skip
	
	-- make sure we have a usable ABI set
	if type(config.abi) == "string" then
		config.abi = {config.abi}
	elseif type(config.abi) ~= "table" then
		config.abi = {"all"}
	end
	for i,v in ipairs(config.abi) do
		if v == "all" then
			config.abi = {
				"armeabi",
				"armeabi-v7a",
				--"x86", --x86 fails on ares and some assembler shenanigans - perhaps fixable with the right flags.
				--"mips", -- mips just fails spectacularly from the start. Fix unlikely, toolchain even states it probably doesn't support.
			}
			break
		end
	end
	
	if config.noop then
		_TEST = true
		print("TEST MODE ENABLED. No file ops permitted.")
		print("This may have unexpected results, but should give an idea as to what's going on.")
		os.execute = function (...) return print("execute:" , ...) end
	end
	
	if config.include then
		external = config.include
	end
	if config.exclude then
		for _,v in ipairs(config.exclude) do
			for i,x in ipairs(external) do
				if v == x then table.insert(disabled,table.remove(external,i)) end
			end
		end
	end
	if config.components then
		components = table.merge(components,config.components)
	end
	for i,v in ipairs(external) do
		libs[v] = true
	end
	
	dirs.source, dirs.target = {},{}
	local s,t = dirs.source,dirs.target
	
	dirs.root = fs.path(root)
	dirs.ndk = c.ndk and fs.path(c.ndk) or fs.path(dirs.root,"ndk")
	dirs.sdk = c.sdk and fs.path(c.sdk) or fs.path(dirs.root,"sdk")
	dirs.cache = c.cache and fs.path(c.cache) or fs.path(dirs.root,"cache")
	dirs.abi = c.abipath or dirs.root
	dirs.export = fs.path(dirs.root,"bin")
	
	-- directories we'll be working in a lot
	s.moai = c.moai and fs.path(c.moai) or fs.path(dirs.root,"moai-dev")
	dirs.jni = fs.path(s.moai,"ant","libmoai","jni")
	dirs.cmake = fs.path(s.moai,"cmake")
	s.hostsource = fs.path(s.moai,"ant","host-source")
	s.project = fs.path(s.hostsource,"source","project")
	s.external = fs.path(s.project,"external")
	s.app = fs.path(s.project,"src","app")
	s.zipline = fs.path(s.project,"src","moai")
	s.res = fs.path(c.res,c.project)
	
	-- directories we'll be sending files to
	t.build = c.build and fs.path(c.build) or fs.path(dirs.root,"build")
	t.root = fs.path(t.build,c.project)
	t.project = fs.path(t.root,c.project)
	t.zipline = fs.path(t.project,"src","com","ziplinegames","moai")
	t.app = fs.path(t.project,"src",string.explode(c.package,"%w+"))
	t.libs = fs.path(t.project,"libs")
	t.lua = fs.path(t.project,"assets",c.workingDir)
	t.res = fs.path(t.project,"res")
	
	-- files requiring special handling
	files.toolchain = fs.path(s.moai,"cmake","host-android","android.toolchain.cmake")
	files.manifest = fs.path(t.project,"AndroidManifest.xml")
	files.classpath = fs.path(t.project,".classpath")
	files.lprops = fs.path(t.project,"local.properties")
	files.pprops = fs.path(t.project,"project.properties")
	files.aprops = fs.path(t.project,"ant.properties")
	files.build = fs.path(t.project,"build.xml")
	files.project = fs.path(t.project,".project")
	
	c.source = type(c.source) == "string" and c.source or fs.path(s.moai,"samples","hello-moai")
	if fs.os == "windows" then
		print("This script will not work properly under Windows.")
		print("Linux (or a Linux VM) is required for now, though running under Cygwin may work as well.")
		os.exit(1,true)
	end
	return tonumber(args.phase)
end

local phase = {}
phase[1] = function (retry)
	print("Entering phase 1: Set and confirm paths")
	print("Project: " .. config.project)
	print("Root directory: " .. dirs.root)
	print("NDK directory: " .. dirs.ndk)
	print("Moai source: " .. dirs.source.moai)
	print("Project destination: " .. dirs.target.project)
	
	print("Included libraries/extensions:")
	for k,v in pairs(libs) do
		if libs[k] then
			print("\t" .. k .. " (" .. string.upper(subout[k] or k) .. ")")
		end
	end
	print("Disabled libraries/extensions:")
	local dis = {}
	for k,v in pairs(libs) do
		-- Since we're here, build up DISABLED_EXT. We use a translation table for some of these.
		-- Observation: A list of extensions able to be disabled would be extremely handy for stuff like this.
		if not v then
			table.insert(dis, string.upper(subout[k] or k))
			print("\t" .. k .. " (" .. dis[#dis] .. ")")
		end
	end
	
	util.prompt()
	if lfs.attributes(files.toolchain) then -- using a recent repo
		local comps = {}
		for k,v in pairs(components) do
			comps[#comps + 1] = "-DMOAI_" .. string.upper(k) .. "=" .. util.bool(v,1)
		end
		local params = table.merge(comps,{
			'-DDISABLED_EXT="' .. table.concat(dis,";") .. ';"', -- trailing semicolon just to be safe, unsure if actually needed but it doesn't break anything that I've seen.
			"-DBUILD_ANDROID=true",
			'-DCMAKE_TOOLCHAIN_FILE="' .. files.toolchain .. '"',
			'-DANDROID_NDK=' .. dirs.ndk,
			'-DCMAKE_BUILD_TYPE=' .. config.buildtype,
			'-DLIBRARY_OUTPUT_PATH_ROOT="' .. dirs.abi .. '"',
		})
		local cmake = "cmake " .. table.concat(params," ") .. " "
		buildcmd = cmake
		
	else -- android toolchain not found, try spacepluk-style
		print("Android toolchain couldn't be found at " .. files.toolchain)
		print("Aborting.")
		os.exit(1,true)
	end
end

-- This should be the same no matter which build method we use.
phase[2] = function (retry)
	util.prompt("Entering phase 2: Building project tree")
	if lfs.attributes(dirs.target.root) then
		print("Deleting existing project structure.")
		util.exec("rm -rf",dirs.target.root)
	end
	-- get the project structure going
	for k,v in pairs(dirs.target) do
		util.exec("mkdir -p", v)
	end
	
	checkresources()
	util.exec("cp -fR", dirs.source.res .. fs.sep .. "*" , dirs.target.res)
	util.exec("mkdir -p", dirs.cache)
	
	-- copy over the manifest and build config files
	for _,v in ipairs{"AndroidManifest.xml","build.xml",".project",".classpath","ant.properties","local.properties","project.properties"} do
		util.exec("cp -f", fs.path(dirs.source.project,v), (fs.path(dirs.target.project)))
	end
	util.exec("cp -f", fs.path(dirs.source.project,"res","values","strings.xml"), (fs.path(dirs.target.project,"res","values","strings.xml")))
	util.exec("cp -f", fs.path(dirs.source.hostsource,"source","init.lua"), (fs.path(dirs.target.project,"assets","init.lua")))
	
	-- This is half the reason for Chainsaw: Easy file lists.
	-- We already have directories created, so it's down to copying all the java files we need to the new project.
	-- The project is NOT usable yet. We have a LOT of placeholders to change.
	
	-- Zipline files
	local list = fs.ls(dirs.source.zipline,false)
	for i,v in ipairs(external) do
		local p = fs.path(dirs.source.zipline, v)
		if p and lfs.attributes(p) then
			list = list:merge(fs.ls(p))
		end
	end
	for i,v in ipairs(list) do
		util.exec("cp -f", v, dirs.target.zipline)
	end
	
	-- Java files for app entry point
	local list = fs.ls(dirs.source.app)
	for i,v in ipairs(list) do
		util.exec("cp -f", v, dirs.target.app)
	end
	
	util.exec("cp -fR", fs.path(config.source) .. "/*", dirs.target.lua)
	
	local list = fs.ls(dirs.target.lua):filter({"%.bat$", "%.sh$"})
	for i,v in ipairs(list) do
		util.exec("rm -f",v)
	end
	
	-- Parse externals, adding to manifest/classpath/project.properties as needed
	for i,v in ipairs(external) do
		local p = fs.path(dirs.source.external, v)
		if lfs.attributes(p) then
			local dir = fs.tree(p)
			for file,fp in pairs(dir) do
				if file == "project" then
					local p = fs.path(dirs.target.root, v)
					util.exec("mkdir -p", p)
					fs.pushd(tostring(fp))
					util.exec("cp -fR", "./*", p) -- funky results otherwise.
					fs.popd()
					-- Figure out which library reference this is...
					local props = fs.read(files.lprops,true)
					local libn = 1
					for i = #props, 1, -1 do
						local x = tonumber(string.match(props[i],"android%.library%.reference%.(%d+)"))
						if x then
							libn = x + 1
							break
						end
					end
					-- ...and point Eclipse to it. Note: This uses an absolute path, so if you plan on moving the project, adjust your references!
					local libstr = fs.read(files.lprops) .. "\nandroid.library.reference." .. libn .. "=../" .. v .. "/"
					fs.write(libstr,files.lprops)
				elseif file == "lib" then
					for x,y in pairs(fp) do
						if string.match(x,"%.jar$") then
							util.exec("cp -fR", tostring(y), dirs.target.libs) -- just in case we hit a directory
						end
					end
				elseif file == "src" then
					for x,y in pairs(fp) do
						util.exec("cp -fR",tostring(y),(fs.path(dirs.target.project,"src")))
					end
				elseif file == "manifest_permissions.xml" then
					chainsaw.stitch(fp, files.manifest, "EXTERNAL PERMISSIONS")
				elseif file == "manifest_declarations.xml" then
					chainsaw.stitch(fp, files.manifest, "EXTERNAL DECLARATIONS")
				elseif file == "classpath.xml" then
					chainsaw.stitch(fp, files.classpath)
				end
			end
		end
	end
end

phase[3] = function (retry)
	util.prompt("Entering phase 3: Refactoring source and build files")
	
	-- replace placeholders
	chainsaw.replace(fs.path(dirs.target.project,"res","values","strings.xml"),{
		["@NAME@"] = config.name,
		["@APP_ID@"] = config.id,
	})
	chainsaw.replace(files.manifest, {
		["@VERSION_CODE@"] = config.versioncode,
		["@VERSION_NAME@"] = config.version,
		["@DEBUGGABLE@"] = tostring(string.lower(config.buildtype) == "release"),
		["@SCREEN_ORIENTATION@"] = config.orientation,
		["@PACKAGE@"] = config.package,
	})
	
	-- little bit of hackery for init.lua and the rest of config.run
	local steps = select(2, string.gsub(config.workingDir,"([/\\])","%1"))
	local initscript = string.rep("../", steps + 1) .. "init.lua"
	table.insert(config.run,1,initscript)
	for i,v in ipairs(config.run) do
		config.run[i] = '"' .. v .. '"'
	end
	
	local ks = setmetatable(config.keystore or {}, {
		__index = function (self,k)
			self[k] = ""
			return self[k]
		end
	})
	fs.ls(dirs.target.root,true):filter("%.properties$"):replace({
		["@KEY_STORE@"] = type(ks.path) == "string" and ks.path ~= "" and fs.path(ks.path) or false,
		["@KEY_ALIAS@"] = ks.alias,
		["@APP_PLATFORM@"] = config.platform,
		["@SDK_ROOT@"] = dirs.sdk,	
	})
	
	-- Am I the only one wishing for a @PROJECT_NAME@ placeholder?
	chainsaw.replace({files.build, files.project}, {
		["@NAME@"] = config.project,
	})
	
	fs.ls(dirs.target.project,true):filter("%.java$"):replace({
		["@PACKAGE@"] = config.package,
		["@WORKING_DIR@"] = config.workingDir,
		["@RUN_COMMAND@"] = "runScripts ( new String [] { " .. table.concat(config.run,", ") .. " } );",
	})
	
	util.exec("chmod -R 777",dirs.target.lua)
end

phase[4] = function (retry)
	print("Entering phase 4: Building native objects")
	local err,msg
	
	local build = {}
	if config.clean and not retry then
		print("Deleting build cache.")
		util.exec("rm -rf", (fs.path(dirs.abi,"libs")))
		util.exec("rm -rf", dirs.cache)
	end
	
	for i,v in ipairs(config.abi) do
		local p,exists = fs.path(dirs.abi,"libs",v,"libmoai.so")
		if exists then -- we've built this ABI already (pass --clean to clear cache beforehand)
			print(v .. " has been built already, skipping.")
		else
			build[i] = buildcmd .. " "
		end
	end
	
	for i,v in ipairs(config.abi) do
		if build[i] then
			local bp = fs.path(dirs.cache,v)
			
			util.exec("mkdir -p", bp)
			fs.pushd(bp)
			
			local e = build[i] .. '-DANDROID_ABI="' .. v .. '" ' .. dirs.cmake
			util.prompt("Configuring ABI " .. v, e)
			local success = util.exec(e)
			if not success then return true,"Configure step failed (" .. v .. ")"
			else util.prompt("Building ABI " .. v) end
			
--			checkabi(v)
			local success = util.exec("cmake --build . --target moai -- -j4")
			if not success then return true,"Build failure (" .. v .. ")"; end
			
			fs.popd()
		end
	end
end

phase[5] = function (retry)
	util.prompt("Entering phase 5: Copying native objects to project")
	local dir = fs.tree((fs.path(dirs.abi,"libs")))
	for file,fp in pairs(dir) do
		if type(fp) == "table" then
			if fp["libmoai.so"] then -- make sure the lib is actually built
				link(tostring(fp),dirs.target.libs)
			end
		end
	end
end

phase[6] = function (retry)
	if config.export then
		util.prompt("Entering Phase 6: Exporting APK")
		fs.pushd(dirs.target.project)
		util.exec("ant ",string.lower(config.buildtype))
		fs.popd()
	end
end

phase[7] = function (retry)
	if config.export then
		util.prompt("Entering Phase 7: Copying APK")
		fs.mkdir(dirs.export)
		local apk
		local tree = fs.ls((fs.path(dirs.target.project,"bin"))):filter(string.lower(config.buildtype) .. "%.apk$")
		for i,v in ipairs(tree) do
			if string.match(v,"%.apk$") then
				util.exec("cp -f", v, (fs.path(dirs.export, config.apkname)))
				print("Copied " .. v .. " to " .. (fs.path(dirs.export, config.apkname)))
			end
		end
	end
end

local start = init()
for i = start, #phase do
	local err,msg
	while true do
		err,msg = phase[i](err)
		if err then
			util.prompt("Errors encountered in phase " .. i, msg, "If the error occurred during cmake, retrying may provide more information.","Continuing will restart the phase.")
		else
			print("Phase " .. i .. " completed.")
			break
		end
	end
end