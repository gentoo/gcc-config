# What is gcc-config?

`gcc-config` allows Gentoo users to switch active gcc safely
and allows querying facts about installed toolchains.

## Usage

To switch active `gcc` while system runs:

```
    $ gcc-config x86_64-pc-linux-gnu-8.1.0
    $ gcc-config x86_64-pc-linux-gnu-7.2.0
```

Ideally changes should be visible instantly and atomically
without shell restart.

To query where real `gcc` binaries are hiding:

```
    $ gcc-config -B $(gcc-config -c)
```

To parse a profile into TARGET and toolchain version:

```
    $ gcc-config -S sparc64-unknown-linux-gnu-9.2.0
```

## Files, variables, things.

- Wrappers (symlinks to compiler binary like `/usr/${CTARGET}/gcc-bin/${GCC_VERSION}/gcc`)

  `/usr/bin/gcc` (native)

  `/usr/bin/g++` (native)

  `/usr/bin/${CTARGET}-gcc` (native and cross)

  ...

  (all files from `/usr/${CTARGET}/gcc-bin/$GCC_VERSION/*`)

  See `gcc-config` script for wrapping details.

  `/usr/bin/c89` (native)

  `/usr/bin/c99` (native)

- private `gcc` configs (provided by `toolchain.eclass`, gcc ebuilds)

  `/etc/env.d/gcc/x86_64-pc-linux-gnu-8.1.0`

Contains variables that describe toolchain layout:

```
          LDPATH="/usr/lib/gcc/x86_64-pc-linux-gnu/8.1.0"
          MANPATH="/usr/share/gcc-data/x86_64-pc-linux-gnu/8.1.0/man"
          INFOPATH="/usr/share/gcc-data/x86_64-pc-linux-gnu/8.1.0/info"
          STDCXX_INCDIR="g++-v8"
          CTARGET="x86_64-pc-linux-gnu"
          GCC_SPECS=""
          MULTIOSDIRS="../lib64"
          GCC_PATH="/usr/x86_64-pc-linux-gnu/gcc-bin/8.1.0"
```

      Used by `gcc-config` to generate wrappers and `05gcc-` `env.d` files.

- `gcc` `env.d` compiler entries (provided by `gcc-config`)

  `/etc/env.d/04gcc-${CTARGET}` (native)

      Populates paths for native-compilers

```
        GCC_SPECS=""
        MANPATH="/usr/share/gcc-data/x86_64-pc-linux-gnu/8.2.0/man"
        INFOPATH="/usr/share/gcc-data/x86_64-pc-linux-gnu/8.2.0/info"
```

Used by `env-update` to populate `$PATH` and more (TODO: remove `$PATH` population).

## TODOs

- Write proper `gcc-config` manpage off this readme to be more discoverable.

- Figure out symlink ownership story. Today symlinks don't belong to any package.

  See [bug 626606](https://bugs.gentoo.org/626606)

## Releasing

```
  $ release=2.3.1; git tag -a -s -m "release ${release}" v${release}; make dist PV=${release}
  $ git push --tags origin
```
