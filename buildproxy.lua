local cli = require "cliargs"
require "util.init"

cli:add_arg("repo","Repo to use")
cli:optarg("id","Package ID","test")
cli:add_flag("-r, --release","Release build")
local args = cli:parse()

local package = "com.taroven." .. args.id
local bpath = "/storage/emulated/legacy/Moai/Eclipse/"
local ppath = bpath .. package

local dis = {"adcolony","billing","chartboost","crittercism","facebook","push","tapjoy"}
for i,v in ipairs(dis) do dis[i] = "--disable-" .. v end
local disabled = table.concat(dis," ")

fs.pushd(args.repo .. "/ant")
print("./make-host.sh -p " .. package .. " -l android-19 -a all " .. disabled)
os.execute("./make-host.sh -p " .. package .. " -l android-19 -a all " .. disabled)
print("Moving project to " .. ppath)
os.execute("mkdir -p " .. bpath)
os.execute("mv untitled-host " .. ppath)
os.execute("chown -R --reference=" .. bpath .. " " .. ppath)
print("Linking project to " .. args.repo .. "/ant/" .. package)
os.execute("rm `pwd`/" .. package)
os.execute("ln -s " .. ppath .. " `pwd`/" .. package)
print("All set. Next up, settings edits.")
fs.popd()