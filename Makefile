GNATFLAGS = -gnatwa -gnat2022 -gnata

.PHONY: all test play run size eph eph-batch clean

all: test

test:
	mkdir -p obj bin
	gnatmake $(GNATFLAGS) -D obj -Isrc tests/tests.adb -o bin/tests
	./bin/tests
	$(MAKE) eph-batch

play:
	mkdir -p obj bin
	gnatmake $(GNATFLAGS) -D obj -Isrc src/play.adb -o bin/play
	./bin/play

size:
	mkdir -p obj bin
	gnatmake $(GNATFLAGS) -D obj -Isrc src/size.adb -o bin/size
	./bin/size

eph-batch:
	mkdir -p obj bin eph
	gnatmake $(GNATFLAGS) -D obj -Isrc src/eph_batch.adb -o bin/eph_batch
	./bin/eph_batch

eph: eph-batch

# Alias used by local clones expecting `make run`
run: play

clean:
	rm -rf obj bin
