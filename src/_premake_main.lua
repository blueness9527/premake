--
-- _premake_main.lua
-- Script-side entry point for the main program logic.
-- Copyright (c) 2002-2014 Jason Perkins and the Premake project
--

	local shorthelp     = "Type 'premake5 --help' for help"
	local versionhelp   = "premake5 (Premake Build Script Generator) %s"


-- Load the collection of core scripts, required for everything else to work

	local manifest = dofile("_manifest.lua")
	for i = 1, #manifest do
		dofile(manifest[i])
	end


-- Create namespaces for myself

	local p = premake
	p.main = {}


--
-- Script-side program entry point.
--

	p.main.elements = function()
		return {
			p.main.installModuleLoader,
		}
	end

	function _premake_main()

		-- Clear out any configuration scoping left over from initialization

		filter {}

		-- Seed the random number generator so actions don't have to do it themselves

		math.randomseed(os.time())

		-- Set some global to describe the runtime environment, building on
		-- what was already set by the native code host

		_PREMAKE_DIR = path.getdirectory(_PREMAKE_COMMAND)

		local file = _OPTIONS["file"] or "premake5.lua"
		local script  = os.locate(file, file .. ".lua", "premake4.lua")
		if script then
			_MAIN_SCRIPT = path.getabsolute(script)
			_MAIN_SCRIPT_DIR = path.getdirectory(_MAIN_SCRIPT)
		else
			_MAIN_SCRIPT_DIR = _WORKING_DIR
		end

		_USER_HOME_DIR = os.getenv("HOME") or os.getenv("USERPROFILE")

		p.callArray(p.main.elements)

		-- Look for and run the system-wide configuration script; make sure any
		-- configuration scoping gets cleared before continuing

		dofileopt(_OPTIONS["systemscript"] or { "premake5-system.lua", "premake-system.lua" })
		filter {}

		-- The "next-gen" actions have now replaced their deprecated counterparts.
		-- Provide a warning for a little while before I remove them entirely.

		if _ACTION and _ACTION:endswith("ng") then
			premake.warnOnce(_ACTION, "'%s' has been deprecated; use '%s' instead", _ACTION, _ACTION:sub(1, -3))
		end

		-- Set up the environment for the chosen action early, so side-effects
		-- can be picked up by the scripts.

		premake.action.set(_ACTION)

		-- If there is a project script available, run it to get the
		-- project information, available options and actions, etc.

		if _MAIN_SCRIPT then
			dofile(_MAIN_SCRIPT)
		end

		-- Process special options

		local action = premake.action.current()

		if (_OPTIONS["version"]) then
			printf(versionhelp, _PREMAKE_VERSION)
			return 1
		end

		if (_OPTIONS["help"]) then
			premake.showhelp()
			return 1
		end

		-- Validate the command-line arguments. This has to happen after the
		-- script has run to allow for project-specific options

		ok, err = premake.option.validate(_OPTIONS)
		if not ok then
			print("Error: " .. err)
			return 1
		end

		-- If no further action is possible, show a short help message

		if not _OPTIONS.interactive then
			if not _ACTION then
				print(shorthelp)
				return 1
			end

			if not action then
				print("Error: no such action '" .. _ACTION .. "'")
				return 1
			end

			if not _MAIN_SCRIPT then
				print("No Premake script (premake5.lua) found!")
				return 1
			end
		end

		-- "Bake" the project information, preparing it for use by the action

		if action then
			print("Building configurations...")
			premake.oven.bake()
		end

		-- Run the interactive prompt, if requested

		if _OPTIONS.interactive then
			debug.prompt()
		end

		-- Sanity check the current project setup

		premake.validate()

		-- Hand over control to the action

		printf("Running action '%s'...", action.trigger)
		premake.action.call(action.trigger)

		print("Done.")
		return 0
	end



---
-- Add a new module loader that knows how to use the Premake paths like
-- PREMAKE_PATH and the --scripts option, and follows the module/module.lua
-- naming convention.
---

	function p.main.moduleLoader(name)
		local shortName = name .. "/" .. name .. ".lua"
		local longName = "modules/" .. shortName
		local chunk = loadfile(shortName) or loadfile(longName)
		if chunk then
			return chunk
		else
			return "\n\tno file " .. moduleName .. " on module paths"
		end
	end

	function p.main.installModuleLoader()
		table.insert(package.loaders, 2, p.main.moduleLoader)
	end
