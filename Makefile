EPREFIX ?=

PN = gcc-config
PV = git
P = $(PN)-$(PV)
BACKUPDIR = gcc-backup

PREFIX = $(EPREFIX)/usr
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(P)
ESELECTDIR = $(PREFIX)/share/eselect/modules

SUBLIBDIR = lib
LIBDIR = $(PREFIX)/$(SUBLIBDIR)
LIBGCC_BACKUPDIR = $(EPREFIX)/$(SUBLIBDIR)/$(BACKUPDIR)

ENVD = $(EPREFIX)/etc/env.d

MKDIR_P = mkdir -p -m 755
INSTALL_EXE = install -m 755
INSTALL_DATA = install -m 644

all: .gcc-config .envd-gcc-backup

clean:
	rm -f .gcc-config .envd-gcc-backup

.gcc-config: gcc-config
	sed \
		-e '1s:/:$(EPREFIX)/:' \
		-e 's:@GENTOO_EPREFIX@:$(EPREFIX):g' \
		-e 's:@GENTOO_LIBDIR@:$(SUBLIBDIR):g' \
		-e 's:@PV@:$(PV):g' \
		-e 's:@GENTOO_GCC_BACKUP_DIR@:$(BACKUPDIR):g' \
		$< > $@
	chmod a+rx $@

.envd-gcc-backup: envd-gcc-backup
	sed \
		-e 's:@LIBGCC_BACKUPDIR@:$(LIBGCC_BACKUPDIR):g' \
		$< > $@

install: all
	$(MKDIR_P) $(DESTDIR)$(BINDIR)
	$(INSTALL_EXE) .gcc-config $(DESTDIR)$(BINDIR)/gcc-config
	$(MKDIR_P) $(DESTDIR)$(ESELECTDIR)
	$(INSTALL_DATA) gcc.eselect $(DESTDIR)$(ESELECTDIR)
	$(MKDIR_P) $(DESTDIR)$(DOCDIR)
	$(INSTALL_DATA) README $(DESTDIR)$(DOCDIR)
	$(MKDIR_P) $(DESTDIR)$(LIBGCC_BACKUPDIR)
	$(INSTALL_DATA) gcc-backup/README $(DESTDIR)$(LIBGCC_BACKUPDIR)
	$(MKDIR_P) $(DESTDIR)$(ENVD)
	$(INSTALL_DATA) .envd-gcc-backup $(DESTDIR)$(ENVD)/99gcc-backup

test check: .gcc-config
	cd tests && ./run_tests

dist:
	@if [ "$(PV)" = "git" ] ; then \
		printf "please run: make dist PV=xxx\n(where xxx is a git tag)\n" ; \
		exit 1 ; \
	fi
	git archive --prefix=$(P)/ v$(PV) | xz > $(P).tar.xz

distcheck: dist
	@set -ex; \
	rm -rf $(P); \
	tar xf $(P).tar.xz; \
	pushd $(P) >/dev/null; \
	$(MAKE) install DESTDIR=`pwd`/foo; \
	rm -rf foo; \
	$(MAKE) check; \
	popd >/dev/null; \
	rm -rf $(P)

.PHONY: all clean dist install
