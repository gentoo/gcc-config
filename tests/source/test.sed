#!/bin/bash
# Make sure gcc-config does not run `sed` directly -- use ${SED}.
grep '\<sed\>' "${GCC_CONFIG}" | grep -v '^: .*SED.*type -P sed' || :
