
FILES = multirun.nim

default: release

autobuild:
	find . -type f -iname \*.nim | entr -c make development

development: ${FILES}
	# can use gdb with this...
	nim --debugInfo --assertions:on --linedir:on -d:noSignalHandler -d:testing -d:nimTypeNames --nimcache:.cache c ${FILES}

release: ${FILES}
	nim -d:release -d:noSignalHandler --opt:size --parallelBuild:0 --nimcache:.cache c ${FILES}
	strip multirun

docs:
	nim doc ${FILES}
	#nim buildIndex ${FILES}

clean:
	cat .hgignore | xargs rm -rf

