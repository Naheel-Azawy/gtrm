PREFIX    = /usr/local
BINPREFIX = $(DESTDIR)$(PREFIX)/bin

FLAGS =            \
	--pkg gtk+-3.0 \
	--pkg vte-2.91

gtrm: gtrm.vala
	valac $(FLAGS) gtrm.vala -o gtrm

install:
	mkdir -p $(BINPREFIX)
	cp -f gtrm $(BINPREFIX)/

uninstall:
	rm -f $(BINPREFIX)/gtrm

clean:
	rm -f gtrm

.PHONY: install uninstall clean
