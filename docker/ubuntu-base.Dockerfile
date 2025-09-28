FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# Core build & runtime deps (added: libffi-dev, gnupg, netbase, xz-utils)
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      build-essential pkg-config \
      libgmp-dev zlib1g-dev libssl-dev libffi-dev \
      libtool autoconf automake \
      rlwrap tmux htop libevent-dev libncurses-dev \
      libpcre++-dev \
      libsodium-dev libzmq3-dev \
      libodbc1 unixodbc unixodbc-dev freetds-bin tdsodbc \
      gnupg netbase xz-utils jq vim && \
    rm -rf /var/lib/apt/lists/*

# Install Haskell Stack (we already installed its deps above)
RUN curl -sSL https://get.haskellstack.org/ | sh -s - -f && stack --version

# Prepare the GHC toolchain Kuro expects (GHC 8.6.5 via lts-13.24)
RUN stack --resolver lts-13.24 setup

WORKDIR /work
CMD ["/bin/bash"]
