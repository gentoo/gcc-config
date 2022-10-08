# configurable options:

# Avoid installing native symlinks like:
#     /usr/bin/gcc -> ${CTARGET}-gcc
# and keep only
#     ${CTARGET}-gcc
USE_NATIVE_LINKS ?= yes
# Install cc/f77 symlinks to gcc/g77.
USE_CC_WRAPPERS ?= yes

# Prepend toolchain prefix to 'gcc' in c89/c99 wrapeprs.
#    Should usually be '${CHOST}-'.
TOOLCHAIN_PREFIX ?=

EPREFIX ?=

PN = gcc-config
PV = git
P = $(PN)-$(PV)

PREFIX = $(EPREFIX)/usr
BINDIR = $(PREFIX)/bin
DOCDIR = $(PREFIX)/share/doc/$(P)
SHAREDIR = $(PREFIX)/share/$(PN)
ESELECTDIR = $(PREFIX)/share/eselect/modules

SUBLIBDIR = lib
LIBDIR = $(PREFIX)/$(SUBLIBDIR)

MKDIR_P = mkdir -p -m 755
INSTALL_EXE = install -m 755
INSTALL_DATA = install -m 644

all: .gcc-config .c89 .c99

clean:
	rm -f .gcc-config .c89 .c99

.gcc-config: gcc-config
	sed \
		-e 's:@GENTOO_EPREFIX@:$(EPREFIX):g' \
		-e 's:@GENTOO_LIBDIR@:$(SUBLIBDIR):g' \
		-e 's:@PV@:$(PV):g' \
		-e 's:@USE_NATIVE_LINKS@:$(USE_NATIVE_LINKS):g' \
		-e 's:@USE_CC_WRAPPERS@:$(USE_CC_WRAPPERS):g' \
		$< > $@
	chmod a+rx $@

.c89: c89
	sed \
		-e '1s:/:$(EPREFIX)/:' \
		-e 's:@PV@:$(PV):g' \
		-e 's:@TOOLCHAIN_PREFIX@:$(TOOLCHAIN_PREFIX):g' \
		$< > $@
	chmod a+rx $@

.c99: c99
	sed \
		-e '1s:/:$(EPREFIX)/:' \
		-e 's:@PV@:$(PV):g' \
		-e 's:@TOOLCHAIN_PREFIX@:$(TOOLCHAIN_PREFIX):g' \
		$< > $@
	chmod a+rx $@

install: all
	$(MKDIR_P) $(DESTDIR)$(BINDIR) $(DESTDIR)$(ESELECTDIR) $(DESTDIR)$(SHAREDIR) $(DESTDIR)$(DOCDIR)
	$(INSTALL_EXE) .gcc-config $(DESTDIR)$(BINDIR)/gcc-config
	$(INSTALL_EXE) .c89 $(DESTDIR)$(SHAREDIR)/c89
	$(INSTALL_EXE) .c99 $(DESTDIR)$(SHAREDIR)/c99
	if [ "$(USE_NATIVE_LINKS)" = yes ] ; then \
		$(INSTALL_EXE) .c89 $(DESTDIR)$(BINDIR)/c89 && \
		$(INSTALL_EXE) .c99 $(DESTDIR)$(BINDIR)/c99 ;  \
	fi
	$(INSTALL_DATA) gcc.eselect $(DESTDIR)$(ESELECTDIR)
	$(INSTALL_DATA) README $(DESTDIR)$(DOCDIR)

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
