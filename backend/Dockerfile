# Utiliser l'image officielle Dart comme base
FROM dart:stable AS build

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY pubspec.yaml .
COPY pubspec.lock .

# Télécharger les dépendances
RUN dart pub get

# Copier le code source
COPY . .

# Compiler l'application Dart en mode release
RUN dart compile exe bin/server.dart -o bin/server

# Étape de production - image minimale
FROM alpine:latest

# Installer les dépendances nécessaires
RUN apk add --no-cache libc6-compat

# Créer un utilisateur non-root
RUN adduser -D dartuser

# Définir le répertoire de travail
WORKDIR /app

# Copier l'exécutable depuis l'étape de build
COPY --from=build /app/bin/server .

# Changer le propriétaire des fichiers
RUN chown -R dartuser:dartuser /app

# Utiliser l'utilisateur non-root
USER dartuser

# Exposer le port 8080
EXPOSE 8080

# Commande pour lancer l'application
ENTRYPOINT ["./server"]