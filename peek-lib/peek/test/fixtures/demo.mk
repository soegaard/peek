CC := gcc

all: main.o util.o
	$(CC) -o app main.o util.o

include local.mk
