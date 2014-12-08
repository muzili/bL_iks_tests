CROSS_COMPILE	?= arm-linux-gnueabihf-
CC		= $(CROSS_COMPILE)gcc
SOURCES		= bl-agitator.c

all: bl-agitator

clean:
	rm -f bl-agitator

bl-agitator:
	$(CC) $(SOURCES) $(CFLAGS) -lrt -lpthread -o bl-agitator
