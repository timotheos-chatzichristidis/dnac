# dnac — portable build (Linux / macOS / MSYS2 / WSL)
# Windows PowerShell users can keep using ./build.ps1 instead.

CC      ?= cc
CFLAGS  ?= -O3 -Wall -Wextra
# -pthread is in LDLIBS, not CFLAGS, because CI passes its own CFLAGS and would
# drop it -- and then -j N would fail to link on a glibc that still separates
# libpthread. Windows toolchains use the Win32 API instead and ignore it.
ifeq ($(OS),Windows_NT)
LDLIBS   = -lm
else
LDLIBS   = -lm -pthread
endif
PREFIX  ?= /usr/local

# Windows toolchains append .exe; without this the target is never satisfied and
# `make test` looks for a file that does not exist.
ifeq ($(OS),Windows_NT)
EXEEXT = .exe
else
EXEEXT =
endif
BIN = dnac$(EXEEXT)

.PHONY: all clean test bench install uninstall

all: $(BIN)

$(BIN): dnac.c
	$(CC) $(CFLAGS) -o $@ dnac.c $(LDLIBS)

# Losslessness proof: adversarial round-trips, SHA-256 verified.
test: $(BIN)
	sh scripts/roundtrip.sh ./$(BIN)

# Bits/base on whatever genomes are present (see scripts/get-data.sh).
bench: $(BIN)
	sh scripts/bench.sh ./$(BIN)

install: $(BIN)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BIN) $(DESTDIR)$(PREFIX)/bin/dnac

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/dnac

clean:
	rm -f dnac dnac.exe feature_test feature_test.exe *.o
