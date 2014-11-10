return {
	name = "Moai SD Loader",
	package = "com.taroven.moailoader",
	id = 000, -- Google Play Services ID (required if using Google ads or Play Services integration)
	
	moai = "[root]/moai-dev",
	source = "/storage/sdcard_ext/Moai/loader",
		
	versioncode = 1, -- numeric representation of version
	version = "1.0", -- actual version string
	
	--abi = "armeabi-v7a",
	
	-- Whitelist (include these modules and their permissions)
	include = { -- is this it?
--		"adcolony",
--		"chartboost",
--		"crittercism",
--		"facebook",
--		"google-billing",
--		"google-play-services",
--		"google-push",
--		"miscellaneous",
--		"tapjoy",
--		"twitter",	
	},
	
	exclude = {
--		"chartboost",
--		"crittercism",
--		"facebook",
--		"google-billing",
--		"google-play-services",
--		"google-push",
--		"miscellaneous",
--		"tapjoy",
--		"twitter",
	},
	
	-- config.components is translated to -DMOAI cmake flags.
	-- Unlike most other parts of the config, this list merges with an internal list of defaults.
	-- In other words: true/false is obeyed, nil goes right back to default instead of acting like false.
	components = {
		untz = true,
		fmod = false,
		luajit = true,
		--luajit = false,
		box2d = true,
		chipmunk = false,
		curl = true,
		crypto = true,
		expat = true,
		freetype = true,
		http_client = false,
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
