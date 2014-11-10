--[[
	This file acts as a global default for the build script. 
	Project-specific variables can be set in config[projectname] (ie, config["test"]) if you like.
	Alternatively, create [projectname].lua in the config directory.
	Load order is:
		global.lua
		{global.lua}[projectname]
		[projectname].lua (final authority)
		
	Any values not set in project-specific locations are pulled from this file or, failing that, defaulted in the build script (if possible).
--]]

local config = {
	noop = false, -- replace os.execute with print. Chainsaw will be neutered as well.
	skip = false, -- skip "Press enter to continue" prompts (automated build)
	export = false, -- export .APK file once build is complete (uses SDK and Ant)
	symlink = true, -- disable this if you don't use a filesystem that support symbolic links (Windows, FAT/32)
	--export = "[root]/build", -- If true, find the apk in build/[project]/bin - if string, copy the apk to the specified path and rename according to version
	--pathsep = "\\", -- uncomment for Windows builds
	
	root = nil, -- working directory (defaults to ./ if not present)
	ndk = "[root]/ndk", -- path to Android NDK (note: [root] will be replaced by this.root)
	sdk = "[root]/sdk", -- path to Android SDK (NOT Eclipse! This needs the CLI tools directory within (look for /tools/ and /platform-tools/ and you have a winner))
	build = "[root]/build", -- where to save project files
	moai = "[root]/moai-dev", -- local Moai repo (change as appropriate if switching Git repos)
	res = "[root]/res", -- where to find custom resources (looks in config.res/[projectname], will copy dummies if needed)
	cache = "[root]/cache", -- path to cmake cache
	--abipath = "[root]", -- path to built Android native objects (will be stored under abipath/libs) (workaround for cmake being stupid)
	
	git = { -- optional: clone/maintain a git repo for the build
		latest = false, -- true: checkout before build (ignored if a moai repo can't be found where specified)
		uri = "https://github.com/moai/moai-dev.git",
--		branch = "master", -- branch, tag, and commit are optional
--		tag = "Version-1.5.2",
--		commit = "HEAD",
	},
	
	platform = "android-19", -- Android API version to target
	abi = "all", -- processors to build for
	--[[
	abi = {
		"armeabi",
		"armeabi-v7a",
--		"x86", -- build failure
--		"mips", -- massive build failure
		-- other entries may be found in moai-dev/cmake/host-android/android.toolchain.cmake
	},
	--]]
	
	buildtype = "Debug", -- ignores keystore
	--build = "Release", -- requires keystore
	keystore = {
		path = "[root]/keystore", -- path to keystore file
		alias = "global", -- saved alias
		pwd = "", -- optional, will prompt if needed
		aliaspwd = "", -- optional, will prompt if needed
	},
	
	orientation = "sensorLandscape", -- screen orientation
	workingDir = "lua",
	run = "main.lua",
	
	-- config.apkname can use any [bracketed] value in config as a tag to build a final filename for exported .APK files.
	-- If not a string, uses "[project]_[version]_[timestamp]-[buildtype]"
	apkname = "[project]_[version]_[timestamp]-[buildtype]",
	timestamp = "%d%m%y_%H%M", -- see os.date documentation for format
	
	-- config.components is translated to -DMOAI cmake flags.
	-- Unlike most other parts of the config, this list merges with an internal list of defaults.
	-- In other words: true/false is obeyed, nil goes right back to default instead of acting like false.
	components = {
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
	},
}

return config