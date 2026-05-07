#!/usr/bin/env python

import os

env = SConscript("thirdparty/godot-cpp/SConstruct")

env.Append(CPPPATH=["src", "include"])

sources = Glob("src/*.cpp")

library_basename = "coursework_extension"

if env["platform"] == "macos":
	library = env.SharedLibrary(
		"demo/bin/{}.{}.{}.framework/{}.{}.{}".format(
			library_basename,
			env["platform"],
			env["target"],
			library_basename,
			env["platform"],
			env["target"],
		),
		source=sources,
	)
elif env["platform"] == "ios":
	if env["ios_simulator"]:
		library = env.StaticLibrary(
			"demo/bin/{}.{}.{}.simulator.a".format(library_basename, env["platform"], env["target"]),
			source=sources,
		)
	else:
		library = env.StaticLibrary(
			"demo/bin/{}.{}.{}.a".format(library_basename, env["platform"], env["target"]),
			source=sources,
		)
else:
	library = env.SharedLibrary(
		"demo/bin/{}{}{}".format(library_basename, env["suffix"], env["SHLIBSUFFIX"]),
		source=sources,
	)

env.NoCache(library)
Default(library)
