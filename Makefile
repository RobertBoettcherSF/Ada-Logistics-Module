GNATFLAGS = -gnatwa -gnat2022 -gnata
GPR = logistics_module.gpr

.PHONY: all test clean

all: test

obj:
	mkdir -p obj

test: obj
	gprbuild -p -P $(GPR) $(GNATFLAGS)
	./obj/tests

clean:
	rm -rf obj
