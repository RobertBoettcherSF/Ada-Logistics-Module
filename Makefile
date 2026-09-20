GNATFLAGS = -gnatwa -gnat2022 -gnata
GPR = logistics_module.gpr

.PHONY: all test play clean

all: test

obj:
	mkdir -p obj

test: obj
	gprbuild -p -P $(GPR) $(GNATFLAGS)
	./obj/tests

play: obj
	gprbuild -p -P $(GPR) $(GNATFLAGS)
	./obj/play

clean:
	rm -rf obj
