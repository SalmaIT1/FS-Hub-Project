# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy configuration files
COPY pubspec.yaml pubspec.lock ./

# Pre-cache dependencies
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Accept the API URL as a build argument
ARG API_BASE_URL
ENV API_BASE_URL=$API_BASE_URL

# Enable web and build release with the injected API URL
RUN flutter config --enable-web && \
    flutter build web --release --dart-define=API_BASE_URL=$API_BASE_URL

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