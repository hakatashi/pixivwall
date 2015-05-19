LIBS = ole32.lib user32.lib shell32.lib Shlwapi.lib Winhttp.lib Pathcch.lib

all: pixivwall.exe

main.obj: main.cpp
	cl main.cpp /c /Fomain.obj

pixivwall.exe: main.obj
	cl main.obj $(LIBS) /Fepixivwall.exe
