#!/bin/bash

# This script's function is to provide an access token to Rust's Cargo build
# tool, as per the following:
#
# https://doc.rust-lang.org/nightly/cargo/reference/registry-authentication.html#cargotoken-from-stdout-command-args
#
# This script performs access control on token requests, checking the URI to
# ensure that tokens are only returned for internal Microsoft registries.
#
# The tool is configured by setting the CARGO_REGISTRY_GLOBAL_CREDENTIAL_PROVIDER
# environment variable to the path to this script, followed by any number of
# arguments representing URL prefixes. When Cargo needs to authenticate with a
# registry, it will invoke this script. This script will check the URL of the
# registry, and if it starts with one of the arguments, it will write the value
# of the SYSTEM_ACCESSTOKEN environment variable to stdout, and return 0 to
# indicate success. Otherwise, it will print an error message to stderr, and
# return 1 to indicate authentication failure.

# Check that SYSTEM_ACCESSTOKEN is set
if [[ -z "$SYSTEM_ACCESSTOKEN" ]]; then
  echo "The environment variable SYSTEM_ACCESSTOKEN is not set." >&2
  echo "This must be set to a PAT with code read and packaging read" >&2
  echo "permission on all repositories and feeds accessed by Cargo." >&2
  exit 1
fi

# Loop through all arguments
for arg in "$@"; do
  if ! [[ $arg =~ https:\/\/* ]]; then
    echo "The provided URL prefix '$arg' does not start with 'https://'" >&2
    echo "and cannot be trusted to be a valid Microsoft registry source." >&2
    echo "Please ensure all URL prefixes are valid HTTPS URLs." >&2
    exit 1
  fi

  if (( ${#arg} < 9 )); then
    echo "The provided URL prefix '$arg' with length ${#arg} has no content." >&2
    echo "Please ensure all URL prefixes are valid actual URLs." >&2
    exit 1
  fi

  if [[ $arg =~ '*/' ]]; then
    echo "The provided URL prefix '$arg' does not end in a slash." >&2
    echo "This means it could be appended to without breaking the prefix." >&2
    echo "Please ensure all URL prefixes end in a slash." >&2
    exit 1
  fi

  # Use regex to check if CARGO_REGISTRY_INDEX_URL starts with the argument
  if [[ $CARGO_REGISTRY_INDEX_URL =~ ^$arg ]]; then
    echo $SYSTEM_ACCESSTOKEN
    exit 0
  fi
done

echo "The value of CARGO_REGISTRY_INDEX_URL ('$CARGO_REGISTRY_INDEX_URL') " >&2
echo "does not start with any of the provided arguments, so no token can" >&2
echo "safely be provided. Returning error code to block authentication." >&2
exit 1
