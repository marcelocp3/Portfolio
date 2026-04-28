GHC = ghc
GHCFLAGS = -O2 -threaded -rtsopts -isrc -L.

.PHONY: build run-sample clean

build: libgmp.so
	$(GHC) $(GHCFLAGS) app/Main.hs -o portfolio

libgmp.so:
	test -e libgmp.so || test ! -e /usr/lib/x86_64-linux-gnu/libgmp.so.10 || ln -s /usr/lib/x86_64-linux-gnu/libgmp.so.10 libgmp.so

run-sample: build
	./portfolio --input data/sample_prices.csv --choose 20 --sims 1000 --workers 4 --limit-combinations 20 +RTS -N4

clean:
	rm -f portfolio libgmp.so app/*.hi app/*.o src/*.hi src/*.o
