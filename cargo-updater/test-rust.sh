#!/bin/bash

echo "Installing Rust toolchain..."

# fail on error
set -e

# List the contents of CARGO_HOME to see if we installed the proper binaries there and got the ownership right.
ls -l $CARGO_HOME
ls -l $CARGO_HOME/bin

# List the contents of $MSRUSTUP_HOME as well
ls -l $MSRUSTUP_HOME

# get the versions of cargo, rustc, msrustup
cargo --version
rustc --version
msrustup --version

# create, build, and delete a tiny temp Rust project
cd ~
cargo new temp_test
cd temp_test
cargo build
cd ..
rm -rf temp_test

# declare victory
echo "All Rust tools were found on PATH and were executable as dependabot user."
