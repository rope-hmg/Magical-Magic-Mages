.PHONY: run

run: build
	./mmm

build:
	~/git/Odin/odin build ./src	\
		-out:mmm				\
		-collection:game=./src	\
		-debug

build-darwin-amd64:
	~/git/Odin/odin build ./src	\
		-out:mmm				\
		-collection:game=./src	\
		-target:darwin_amd64	\
		-debug

run-ld: build-ld
	./ld

build-ld:
	~/git/Odin/odin build ./level-designer \
		-out:ld					\
		-collection:game=./src  \
		-debug
