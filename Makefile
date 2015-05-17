LIBS = ole32.lib user32.lib shell32.lib

all: main.exe

main.obj: main.cpp
	cl main.cpp /c /Fomain.obj

main.exe: main.obj
	cl main.obj $(LIBS) /Femain.exe
