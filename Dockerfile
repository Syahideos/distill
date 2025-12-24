# Build stage
FROM rust:slim-bookworm AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy manifests first for dependency caching
COPY Cargo.toml Cargo.lock ./
RUN mkdir -p src/bin && \
    echo "fn main() {}" > src/main.rs && \
    echo "fn main() {}" > src/bin/loadtest.rs
RUN cargo build --release --bin distill && \
    rm -rf src target/release/distill target/release/deps/distill* target/release/.fingerprint/distill*

# Build actual application
COPY src ./src
RUN touch src/main.rs && cargo build --release --bin distill

# Runtime stage
FROM debian:bookworm-slim

WORKDIR /app

# Install runtime dependencies + Chromium
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    chromium \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /app/target/release/distill /app/distill

# Chrome configuration for container environment
ENV CHROME_PATH=/usr/bin/chromium
ENV CHROME_NO_SANDBOX=1

# Default environment
ENV PORT=3000
ENV MAX_CONCURRENT_TABS=10
ENV RUST_LOG=distill=info

EXPOSE 3000

CMD ["/app/distill"]
