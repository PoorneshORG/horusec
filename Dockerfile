# Stage 1: Build the gitleaks binary
FROM golang:1.22-alpine AS builder

ENV GOTOOLCHAIN=auto

WORKDIR /app

# Install git
RUN apk add --no-cache git

# Clone gitleaks
# RUN git clone https://github.com/gitleaks/gitleaks.git .
RUN git clone https://github.com/PoorneshORG/gitleaks-fork.git .
RUN go build -o gitleaks .

# Stage 2: Create a minimal runtime image
FROM alpine:3.19

# Add ca-certificates if needed
RUN apk add --no-cache ca-certificates

# Copy binary from builder
COPY --from=builder /app/gitleaks /usr/local/bin/gitleaks

# Copy the gitleaks.toml config file
COPY --from=builder /app/config/gitleaks.toml /etc/gitleaks.toml

# Verify installation
RUN gitleaks version

# Default command
ENTRYPOINT ["gitleaks"]
