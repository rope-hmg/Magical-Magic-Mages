all:
	odin run ./src -debug -extra-linker-flags:"-L/opt/homebrew/lib" -out:mmm
