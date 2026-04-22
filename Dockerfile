# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy configuration files
COPY pubspec.yaml pubspec.lock ./

# Pre-cache dependencies
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Enable web and build release
RUN flutter config --enable-web && \
    flutter build web --release

# Stage 2: Production environment using Nginx
FROM nginx:alpine

# Copy the built web assets
COPY --from=build /app/build/web /usr/share/nginx/html

# Copy the Nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]