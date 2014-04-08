all:
	luac32bit -s -o FotosidanAPIKeys.lua FotosidanAPIKeys.lua.src 

release:
	cp *.lua *.png ../fotosidan.lrplugin
	cd ..; zip -r fotosidan.lrplugin.zip fotosidan.lrplugin
