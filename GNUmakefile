.PHONY: all test time clean distclean dist distcheck upload distupload

all: test

dist:
	rm -rf inc META.yaml
	perl Makefile.PL
	$(MAKE) -f Makefile dist

distclean test tardist: Makefile
	make -f $< $@

Makefile: Makefile.PL
	perl $<

clean: distclean

reset: clean
	perl Makefile.PL
	make -f Makefile test
