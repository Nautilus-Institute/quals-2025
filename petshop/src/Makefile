
CC = dmd
CFLAGS = -g -O -release -inline -boundscheck=off -L=--gc-sections -L=--version-script=linker.script

all: petshop

petshop: portal.d ipp.d printer.d bitmap.d
	$(CC) $(CFLAGS) portal.d printer.d ipp.d bitmap.d -ofpetshop
	cp petshop petshop_d
	strip --strip-all petshop

clean:
	rm -f petshop.o
	rm -f petshop petshop_d
