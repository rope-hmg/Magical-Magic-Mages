client:
	odin run ./src/client -debug -extra-linker-flags:"-L/opt/homebrew/lib" -out:mmm

server:
	odin run ./src/server -debug -extra-linker-flags:"-L/opt/homebrew/lib" -out:mmm
