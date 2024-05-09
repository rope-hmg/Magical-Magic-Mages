all:
	odin run ./src/client -debug -extra-linker-flags:"-L/opt/homebrew/lib" -out:mmm
