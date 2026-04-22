# Stage 1: Build the Dart backend
FROM dart:stable AS build

WORKDIR /app

# Copy configuration files
COPY pubspec.yaml pubspec.lock ./

# Download dependencies
RUN dart pub get

# Copy the rest of the application code
COPY . .

# Compile the application to a native executable
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal production image
FROM alpine:latest

# Install necessary runtime dependencies
RUN apk add --no-cache libc6-compat ca-certificates

# Create a non-root user for security
RUN adduser -D dartuser
WORKDIR /app

# Copy the compiled binary from the build stage
COPY --from=build /app/bin/server .

# Set ownership to the non-root user
RUN chown -R dartuser:dartuser /app

# Use the non-root user
USER dartuser

# Expose the API port
EXPOSE 8080

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

# Start the server
ENTRYPOINT ["./server"]