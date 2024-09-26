# Construct a Docker image based on the GitHub one, but replacing the public Rust tools
# with the internal Microsoft Rust tools. Since the internal Microsoft Rust tools support
# the same Cargo commands, existing Dependabot code should continue to work as expected.

FROM ghcr.io/dependabot/dependabot-updater-cargo

ENV RUST_VERSION=ms-1.80.1

COPY ./install-rust.sh /tmp/
COPY ./install-msrustup.sh /tmp/
COPY ./test-rust.sh /tmp/

USER root

# Clean up CARGO_HOME/bin, make scripts executable, install jq
RUN rm -f $CARGO_HOME/bin/* && chmod +x /tmp/install-rust.sh && chmod +x /tmp/install-msrustup.sh && apt-get update && apt-get install -y --no-install-recommends jq

# Initialize Rust related environment variables
ENV CARGO_REGISTRY_GLOBAL_CREDENTIAL_PROVIDERS=cargo:token
ENV MSRUSTUP_HOME=/opt/msrustup

#
# Install Azure Artifacts Credential Provider (needed???)
#
#RUN tdnf update -qy tdnf && \
#        tdnf install -qy azure-cli dotnet-runtime-6.0 && \
#        az extension add --name azure-devops && \
#        wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash

#
# Install git-credential-manager
#
#RUN --mount=type=secret,id=SYSTEM_ACCESSTOKEN \
#        VSS_NUGET_ACCESSTOKEN=$(cat /run/secrets/SYSTEM_ACCESSTOKEN) \
#        dotnet tool install --global git-credential-manager --version 2.1.2 --configfile /tmp/nuget.config

#
# Install Azure Powershell Modules
#
#RUN pwsh -Command "Install-Module -Name Az.Accounts -Repository PSGallery -Force" && \
#    pwsh -Command "Install-Module -Name Az.Resources -Repository PSGallery -Force"

# Install Rust; do this as root so it can muck around with /opt etc.
#
RUN --mount=type=secret,id=SYSTEM_ACCESSTOKEN \
    #    az extension add --name azure-devops && \
    #    wget -qO- https://aka.ms/install-artifacts-credprovider.sh | bash && \
    #    git-credential-manager configure && \
    /tmp/install-rust.sh

# Set ownership to dependabot, recursively, and across symlinks
RUN chown -RL dependabot:dependabot $CARGO_HOME && chown -RL dependabot:dependabot $MSRUSTUP_HOME
# and unset RUSTUP_HOME
ENV RUSTUP_HOME=
# and clean up the scripts
RUN rm /tmp/install-rust.sh /tmp/install-msrustup.sh

# Test that we can run cargo etc. as dependabotl this script will fail if we can't
RUN chmod +x /tmp/test-rust.sh && chown dependabot:dependabot /tmp/test-rust.sh

# Switch back to dependabot from root
USER dependabot

RUN /tmp/test-rust.sh && rm /tmp/test-rust.sh
