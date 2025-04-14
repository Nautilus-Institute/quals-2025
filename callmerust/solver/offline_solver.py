from bitarray import bitarray

bitmap.setall(False)
bitmap = bitarray(2**32)

def rr(s,M):
    a = 1664525
    c = 1013904223
    m = M
    for i in range(s%3+7):
        s = (a*pow(s,65537,281474976710665)+c)%m
    return s
    
    
M=pow(2,32)
ss = set()
for i in range(0,M):
    if i % 10000000 == 0:
        print(i)
    bitmap[rr(i,M)]=True
fd = open("/var/tmp/f1","wb")
bitmap.tofile(fd)
