
default: base64.o buffer.o keycache.o esession.o

base64.o:
	gcc -c base64.c -Wall -Werror

buffer.o: buffer.h
	gcc -c buffer.c -Wall -Werror

keycache.o:
	gcc -c keycache.c -Wall -Werror

esession.o: keycache.o buffer.o base64.o
	gcc -c esession.c -Wall -Werror
