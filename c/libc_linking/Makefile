CC = gcc
CFLAGS = -Wall -I./external

SRC = main.c utils.c
OBJ = $(SRC:.c=.o)
TARGET = my_app

EXT_LIB = -L./external -lhello

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) -o $@ $^ $(EXT_LIB)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f *.o $(TARGET)
