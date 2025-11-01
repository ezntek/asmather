CC ?= cc
CFLAGS ?= -O2 -pipe -march=native
LD ?= ld

build: build-c build-asm

build-c:
	$(CC) $(CFLAGS) -o asmather_c asmather.c
	
build-asm:
	nasm -felf64 -g -o asmather.o asmather.nasm
	$(CC) -no-pie -lc -o asmather asmather.o

clean:
	rm -f asmather *.o
