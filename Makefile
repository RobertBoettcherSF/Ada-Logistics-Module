GNATFLAGS = -gnatwa -gnat2022 -gnata

.PHONY: all test play clean

all: test

test:
	mkdir -p obj bin
	gnatmake $(GNATFLAGS) -D obj -Isrc tests/tests.adb -o bin/tests
	./bin/tests

play:
	mkdir -p obj bin
	gnatmake $(GNATFLAGS) -D obj -Isrc src/play.adb -o bin/play
	./bin/play

clean:
	rm -rf obj bin
