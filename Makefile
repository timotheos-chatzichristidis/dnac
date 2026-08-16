# dnac — portable build (Linux / macOS / MSYS2 / WSL)
# Windows PowerShell users can keep using ./build.ps1 instead.

CC      ?= cc
CFLAGS  ?= -O2 -Wall -Wextra
LDLIBS   = -lm
PREFIX  ?= /usr/local

.PHONY: all clean test bench install uninstall

all: dnac

dnac: dnac.c
	$(CC) $(CFLAGS) -o $@ dnac.c $(LDLIBS)

# Losslessness proof: adversarial round-trips, SHA-256 verified.
test: dnac
	sh scripts/roundtrip.sh ./dnac

# Bits/base on whatever genomes are present (see scripts/get-data.sh).
bench: dnac
	sh scripts/bench.sh ./dnac

install: dnac
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 dnac $(DESTDIR)$(PREFIX)/bin/dnac

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/dnac

clean:
	rm -f dnac dnac.exe feature_test feature_test.exe *.o
