#!/bin/bash

# This script runs as root in order to be able to install into /opt/rust.
echo "Installing Rust toolchain as root..."

# fail on error
set -e

# This script is specific to the ADODependabot project.
# It first deletes the pre-existing public Rust toolchain in the GitHub Dependabot container.
# It then invokes the standard install-msrustup.sh script to install the internal Rust toolchain.
# Finally it customizes the environment to ensure the internal toolchain is accessible as Dependabot expects.

# Installs the toolchain for each RUST_VERSION specified in the base.Dockerfile.
# If this toolchain is compatible with SA for Rust (Rust 1.70 or later) then additionally install static analysis components.
install_rust_toolchains() {
    local rust_versions=("$@")
    for version in "${rust_versions[@]}"; do
        "$MSRUSTUP_HOME/msrustup" --verbose toolchain install "$version" -t x86_64-unknown-linux-gnu
    done
}


# This must have been populated into the container's /run/secrets directory by the `--secret`
# argument to `docker build`.
export SYSTEM_ACCESSTOKEN=$(</run/secrets/SYSTEM_ACCESSTOKEN)

# B4PR: remove this; this is just for local testing
export MSRUSTUP_FEED_URL="https://devdiv.pkgs.visualstudio.com/DevDiv/_packaging/Rust.Sdk/nuget/v3/index.json"

# B4PR: for pipeline, should be: export MSRUSTUP_ACCESS_TOKEN=$SYSTEM_ACCESSTOKEN
export MSRUSTUP_PAT=$SYSTEM_ACCESSTOKEN 

# Install the internal Rust toolchain.
/tmp/install-msrustup.sh

# what happen?
ls -l

# Move msrustup executable to $MSRUSTUP_HOME.
mkdir $MSRUSTUP_HOME
mv ./msrustup $MSRUSTUP_HOME

# Get debugging logging from msrustup.
#export MSRUSTUP_LOG=debug

# RUST_VERSION is set in the Dockerfile.
# If we want to install multiple versions (to allow controlled update), add separate env vars for the
# additional versions there, and then add them in this list.
rust_versions=("$RUST_VERSION")

# Install the Rust toolchain for each RUST_VERSION specified.
install_rust_toolchains "${rust_versions[@]}"

# Set the default toolchain to the default version specified. 
"$MSRUSTUP_HOME/msrustup" default $RUST_VERSION

# List the contents of CARGO_HOME to see if we installed the proper binaries there.
ls -l $CARGO_HOME
ls -l $CARGO_HOME/bin

# List the contents of $MSRUSTUP_HOME as well
ls -l $MSRUSTUP_HOME

# And we're done!
echo "Rust toolchain installed."

# And make sure it's all there and on the PATH as of the end of this script
# (we will subsequently run these commands again once we change back to being the dependabot user)
msrustup --version
cargo --version
rustc --version

