# Utiliser une image Ubuntu avec Flutter pré-installé
FROM ubuntu:22.04

# Éviter les questions interactives
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances système
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer Flutter
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="$FLUTTER_HOME/bin:$FLUTTER_HOME/bin/cache/dart-sdk/bin:$PATH"

RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME --branch stable --depth 1

# Pré-télécharger les artefacts Dart
RUN flutter precache

# Accepter les licences
RUN yes "y" | flutter doctor --android-licenses || true

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY pubspec.yaml .
COPY pubspec.lock .

# Télécharger les dépendances
RUN flutter pub get

# Copier le code source
COPY . .

# Builder l'application en mode release pour web
RUN flutter build web --release

# Étape de production - serveur web Nginx
FROM nginx:alpine

# Copier les fichiers build depuis l'étape précédente
COPY --from=0 /app/build/web /usr/share/nginx/html

# Copier la configuration Nginx personnalisée
COPY nginx.conf /etc/nginx/nginx.conf

# Exposer le port 80
EXPOSE 80

# Commande pour lancer Nginx
CMD ["nginx", "-g", "daemon off;"]