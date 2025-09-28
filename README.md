# Kuro – Local 4-Node Cluster

This repository demonstrates how to spin up a **4-node Kuro cluster** locally using Docker.  
We updated the base image from **Ubuntu 16.04 → Ubuntu 22.04**, dropped the FPComplete apt repo, and now install Stack directly.

---

## ⚙️ Prerequisites

- Ubuntu host (e.g. AWS EC2)
- Installed:
  - Docker
  - `git`, `build-essential`, `curl`, `jq`
- Open ports: **8000-8003**

---

## 🚀 Steps

### 1. Clone the repo

```bash
git clone
cd kuro
```

## Build the base Docker image

We replaced the old 16.04 base with Ubuntu 22.04.

docker/ubuntu-base.Dockerfile:

FROM ubuntu:22.04

```bash 
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
      ca-certificates curl wget git \
      build-essential pkg-config \
      libgmp-dev zlib1g-dev libtinfo5 libncurses5 \
      libssl-dev libffi-dev libpcre3-dev \
      libsqlite3-dev libzmq3-dev \
      python3-minimal \
    && rm -rf /var/lib/apt/lists/*

# Install Stack
RUN curl -sSL https://get.haskellstack.org/ | sh -s - -f && stack --version

# GHC toolchain
RUN stack --resolver lts-13.24 setup

WORKDIR /work
```

## Build it:

```sudo docker build -t kadena-base:ubuntu-16.04 -f docker/ubuntu-base.Dockerfile . ```

## 3 uild Kuro binaries

```bash
UIDGID="$(id -u):$(id -g)"
sudo docker run --rm -it \
  -v "$PWD":/work \
  -w /work \
  -e STACK_ROOT=/work/.stack \
  --user "$UIDGID" \
  kadena-base:ubuntu-16.04 \
  bash -lc 'stack build :kadenaserver :kadenaclient :genconfs --fast --no-run-tests --ghc-options "-j$(nproc)" && mkdir -p bin && cp -f .stack-work/install/*/*/*/bin/{kadenaserver,kadenaclient,genconfs} bin/'
```

You now have:

```bash
bin/kadenaserver
bin/kadenaclient
bin/genconfs
```

## Generate configs

```bash
rm -f conf/* || true
printf "\n\n4\n\n\n\n\n\n\n\n\n\n\n\n" | ./bin/genconfs
ls conf
```

You should see configs like:

```bash
10000-cluster.yaml 10001-cluster.yaml 10002-cluster.yaml 10003-cluster.yaml
admin0-keypair.yaml client.yaml
```

## Run the 4-node cluster

```bash
Option A – host networking (recommended):

sudo docker run -d --name kuro0 --network host -v "$PWD":/work -w /work \
  kadena-base:ubuntu-16.04 /work/bin/kadenaserver --config conf/10000-cluster.yaml

sudo docker run -d --name kuro1 --network host -v "$PWD":/work -w /work \
  kadena-base:ubuntu-16.04 /work/bin/kadenaserver --config conf/10001-cluster.yaml

sudo docker run -d --name kuro2 --network host -v "$PWD":/work -w /work \
  kadena-base:ubuntu-16.04 /work/bin/kadenaserver --config conf/10002-cluster.yaml

sudo docker run -d --name kuro3 --network host -v "$PWD":/work -w /work \
  kadena-base:ubuntu-16.04 /work/bin/kadenaserver --config conf/10003-cluster.yaml
```

Check:

```bash
sudo docker ps
tail -n 50 log/node*.log
```

## Start the client REPL

```bash
sudo docker run -it --network host \
  -v "$PWD":/work -w /work \
  kadena-base:ubuntu-16.04 \
  /work/bin/kadenaclient --config conf/client.yaml
```

## Inside REPL:

```bash
node0> server 127.0.0.1:8000
127.0.0.1:8000> format raw
127.0.0.1:8000> local "(+ 1 2)"


You should see a success response.
For a transaction:

127.0.0.1:8000> keys conf/keys-admin.yaml
127.0.0.1:8000> exec "(+ 1 2)"
```

## Example contract deployment

Create a simple Pact file:

```bash
my/hello.pact:

(module hello GOV
  (defcap GOV () true)
  (defun ping:string () "pong")
)
```

Deploy YAML:

```bash
my/hello-deploy.yaml:

type: exec
codeFile: my/hello.pact
data:
  GOV:
    keys: ["<your-admin-public-key>"]
    pred: "keys-all"
keyPairs:
  - public: "<your-admin-public-key>"
    secret: "<your-admin-secret-key>"
    scheme: ED25519
nonce: "deploy-hello-1"
```

In client REPL:

```bash
127.0.0.1:8000> load my/hello-deploy.yaml
```

## Clean up

```bash
sudo docker rm -f kuro0 kuro1 kuro2 kuro3 || true
rm -rf .stack .stack-work bin log conf
```

## 🔑 Notes

Change made: Base image moved from Ubuntu 16.04 → 22.04; removed FPComplete apt repo; Stack installed via official script.

Use format raw in the REPL to see JSON including request keys.

Logs are written to log/node*.log.

## ✅ Summary

This setup runs a local 4-node Kuro cluster in Docker with modern Ubuntu 22.04 base, full client REPL, and sample contract deployment.