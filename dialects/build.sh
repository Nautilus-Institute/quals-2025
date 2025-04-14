rm ctf solver build/*.o

gcc -I/opt/cross/include -fPIC  -c -o build/ctf.o -Os  src/ctf.c
gcc -I/opt/cross/include  -c -o build/solver.o -Os -g src/solver.c

gcc -fPIC -o ctf build/ctf.o -L/opt/cross/lib64 -lssl -lcrypto  --static 
gcc -o solver build/solver.o -L/opt/cross/lib64 -lssl -lcrypto  --static 

strip ctf

#upx ctf

#./ctf
