CC ?= cc
CFLAGS ?= -fsanitize=address -ggdb

build: build-c build-asm

build-c:
	$(CC) $(CFLAGS) -o asmather asmather.c
	
build-asm:

clean:
	rm asmather *.o
