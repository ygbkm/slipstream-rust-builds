FROM rust:1.92.0-trixie AS builder

# Dependencies
ARG DEPS="\
	ca-certificates \
	build-essential \
	pkg-config \
	cmake \
	clang \
	libssl-dev \
	python3 \
	git \
"
ARG DEBIAN_FRONTEND=noninteractive
RUN \
	apt-get update && \
	apt-get install -y --no-install-recommends $DEPS && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Source
WORKDIR /src
COPY src/ .

# Args
ARG CLIENT_OR_SERVER
RUN test -n $CLIENT_OR_SERVER

# Build
ARG CARGO_HOME=/cargo
ARG CARGO_TARGET_DIR=/cargo/target
RUN cargo build --release --package=slipstream-$CLIENT_OR_SERVER

# ==================================================

FROM debian:trixie-slim AS runner

# Dependencies
ARG DEPS="\
	ca-certificates \
	libssl3 \
	tini \
"
ARG DEBIAN_FRONTEND=noninteractive
RUN \
	apt-get update && \
	apt-get install -y --no-install-recommends $DEPS && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Args
ARG CLIENT_OR_SERVER
RUN test -n $CLIENT_OR_SERVER

# Binary
WORKDIR /app
COPY \
	--from=builder \
	--chmod=755 \
	/cargo/target/release/slipstream-$CLIENT_OR_SERVER \
	/app/slipstream-$CLIENT_OR_SERVER

# User
RUN useradd --create-home slip && chown --recursive slip:slip /app
USER slip

# Entrypoint
EXPOSE 53
ENV CLIENT_OR_SERVER=$CLIENT_OR_SERVER
ENTRYPOINT [ "sh", "-c", "exec tini -- /app/slipstream-${CLIENT_OR_SERVER:?} \"$@\"", "sh" ]
