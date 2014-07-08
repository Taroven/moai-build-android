moai-build-android
==================

##Concept
Moai's Android build scripts, for the most part, work. They'll create a working Eclipse project, build it using Ant, and install/run on a connected device. But there's issues in the mix:
- There's little to no concept of multiple project support.
- Very little automation. Writing a script to run a script gets old quick. 
- The scripts are written in bash. We're Lua developers, goshdarnit.

With those points in mind, I set out to make something a little... different. The result is a complete replacement of the Android shell scripts and their config.

##Dependencies
Linux (or probably OSX) is a must, for now, though you might get away with using cygwin or some creative editing if you run Windows. Actual Windows support is on the wishlist.
I've only tested using Lua 5.2. Lua 5.1.x and LuaJIT should work either out of the box or with very slight modification.

Check the Moai readmes for cmake build dependencies.

A symlink-capable filesystem is HIGHLY recommended, and required for parts of the NDK.

Lua dependencies:
- cliargs - `luarocks install lua_cliargs`
- luafilesystem - `luarocks install luafilesystem`

Another lib, `chainsaw` (written by me), is included in the repo. True to its name, Chainsaw is mean, ugly, and can kill things very dead if improperly handled. Use extreme caution if you want to use or change it. Some safeties are in place to make sure it doesn't nuke your root filesystem.

##Recommended Setup
1. Clone, install dependencies.
2. Install the Android NDK, as well as ADT or Android Studio if you haven't already. Don't worry about environment variables, they're not needed here.
3. The Android SDK comes in two parts: The IDE (Eclipse or Studio) and the SDK. Make a note of the SDK directory, you'll need it soon.
4. Clone your favorite cmake-capable Moai repo.

Now we're ready to do some symlinking. Using your terminal... (replace /script/ with this build script's directory)
NOTE: You can rename these however you like, or just adjust `config/global.lua` to match your setup. This follows the defaults. 

1. `cd /script/`
2. `ln -s /path/to/NDK /script/ndk`
3. `ln -s /path/to/SDK /script/sdk`
4. `ln -s /path/to/Moai /script/moai-dev`

##Configuration
This script uses Lua tables for configuration, located in the config directory:
- `config/global.lua` contains global defaults and may also hold project-specific settings.
- `config/[project].lua` (named after the project name passed to build.lua) holds project-specific settings only.
`global.lua` included in this repo contains sensible defaults and plenty of comments.
`test.lua` included in this repo will fire off a typical test case and is worth a good read as well.

##CLI Configuration
Some overrides are available via the command line when running the build script. You can get some information on them by running:
```
lua build.lua -h
```

Of these, the most commonly used would be `--skip`, `--export`, and/or `--clean`. Any of these may be set via configuration files, the CLI options just make for less editing.

##Execution
Adjust `global.lua` to your liking, check through `test.lua` as well, and run...
```
lua build.lua test
```

The script goes through a total of 7 (at the time if this writing) phases with a prompt between each so you can see what's going on.

1. Verification (make sure settings are correct)
2. Create project structure (copy source and externals to build/[project]), also does some refactoring in the process.
3. Refactoring (nuke placeholders, this is where Chainsaw shines)
4. Cmake configuration and build step, allows preview of commands and shows full process for each Android arch.
5. Symlink or copy built libs to the project structure
6. Build and export Android APK on the spot (requires SDK and installed Apache Ant)
7. Copy built and signed APK to its final location (uses a tagging and timestamp system for archival purposes)
