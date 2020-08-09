#!/bin/bash

# Build yosys + GHDL synthesizer fully open source toolchain for FPGA bitstreams

# build prerequisites: gnat-8 or newer (https://www.adacore.com/download)
# and libffi-dev and tcl-dev (probably in your distro repo).
# It'll use libreadline-dev if present.

# We use nproc to autodetect parallism, use "taskset 1 COMMAND..." to thwart

# where to install to

[ -z "$PREFIX" ] && PREFIX=~/yogh
echo "Installing into $PREFIX"
export PATH="$PREFIX/bin:$PATH"

# In this toolchain, ghdl = clang, ghdlsynth-beta = llvm, yosys = binutils,
# and yosys internally uses abc (optimizer plumbing).
#
# We need all 4 to produce a bitstream.

# Check out or update the 3 repositories

for i in ghdl/ghdl tgingold/ghdlsynth-beta YosysHQ/yosys berkeley-abc/abc
do
  if ! cd $(basename $i) 2>/dev/null
  then
    git clone https://github.com/$i || exit 1
    continue;
  fi
  [ -z "$NOCLEAN" ] && git clean -fdx
  if [ -z "$NONET" ]
  then
    git pull || exit 1
  fi
  cd ..
done

# Build each repo

# todo: yosys does a "git clone" of ABC in the middle of the build,
# integrate that into the above git pull stuff and disable in the makefile
# so we can build it without network access.

cd yosys || exit 1
# If you haven't got clang, use gcc
! which clang && X=CONFIG=gcc
# Don't use libreadline-dev when not installed. Note: not cross-compile aware.
[ ! -e /usr/include/readline/readline.h ] && X="$X ENABLE_READLINE=0"
# Use the optimizer revision the yosys guys regression tested
if [ ! -e abc ]
then
  ln -sf ../abc abc &&
  ABCREV=$(sed -n 's/^ABCREV *= *//p' Makefile)
  cd abc &&
  git checkout $ABCREV &&
  cd .. || exit 1
fi
make PREFIX="$PREFIX" all install -j $(nproc) $X ABCPULL=0 &&
cd .. || exit 1

cd ghdl &&
./configure --enable-libghdl --enable-synth --prefix="$PREFIX" &&
#make && make install &&
make all install -j $(nproc)
cd .. || exit 1

cd ghdlsynth-beta &&
make all install -j $(nproc) &&
cd .. || exit 1
