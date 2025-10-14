.PHONY: run

run: build
	./mmm

build:
	~/git/Odin/odin build ./src \
		-out:mmm				\
		-collection:game=./src  \
		-debug

run-ld: build-ld
	./ld

build-ld:
	~/git/Odin/odin build ./level-designer \
		-out:ld					\
		-collection:game=./src  \
		-debug
