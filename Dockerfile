# Stage 1: Build the gitleaks binary
FROM golang:1.23.10-alpine3.21 AS builder

ENV GOTOOLCHAIN=auto

WORKDIR /app

# Install git for cloning and build-time dependencies
RUN apk add --no-cache git

# Clone custom fork of gitleaks
RUN git clone https://github.com/PoorneshORG/gitleaks-fork.git .
RUN go build -o gitleaks .

# Stage 2: Create a minimal runtime image
FROM alpine:3.21

# Install runtime dependencies: git (required by gitleaks), and certs
RUN apk add --no-cache git ca-certificates

# Copy gitleaks binary and config from the builder stage
COPY --from=builder /app/gitleaks /usr/local/bin/gitleaks

COPY --from=builder /app/config/gitleaks.toml /etc/gitleaks.toml

# Optional: verify the binary works
RUN gitleaks version

# Set default entrypoint
ENTRYPOINT ["gitleaks"]
