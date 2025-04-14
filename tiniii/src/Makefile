
all: tiniii tiniii.7z

stamp_roll.incl: gen_incl.py
	python gen_incl.py

queries.incl: gen_incl.py
	python gen_incl.py

tiniii: tiniii.c md5.c stamp_roll.incl queries.incl process_asm.py
	gcc -S -o tiniii.orig.s tiniii.c -masm=intel -fcf-protection=none -mno-red-zone
	gcc -S -o md5.orig.s md5.c -masm=intel -fcf-protection=none -mno-red-zone
	python process_asm.py tiniii.orig.s tiniii.s
	python process_asm.py md5.orig.s md5.s
	gcc -o tiniii tiniii.s md5.s
	cp tiniii tiniii.orig
	strip --strip-all tiniii

tiniii.7z: tiniii
	7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on tiniii.7z tiniii

clean:
	rm -f tiniii.s tiniii.orig.s md5.s md5.orig.s
	rm -f tiniii tiniii.orig
	rm -f stamp_roll.incl queries.incl
