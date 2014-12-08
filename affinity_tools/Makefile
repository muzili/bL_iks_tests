CROSS_COMPILE	?= arm-linux-gnueabihf-
CC		= $(CROSS_COMPILE)gcc
SOURCES		= affinity_tools.c

all: affinity_tools

clean:
	rm -f affinity_tools

affinity_tools:
	$(CC) $(SOURCES) $(CFLAGS) -lrt -lpthread -o affinity_tools
