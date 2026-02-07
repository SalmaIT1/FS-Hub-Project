# Utiliser une image avec Flutter pré-installé pour éviter les erreurs de dépendances et accélérer le build
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY pubspec.yaml pubspec.lock ./

# Télécharger les dépendances
# Note: On ignore les erreurs de precache qui peuvent survenir parfois
RUN flutter pub get

# Copier le code source
COPY . .

# S'assurer que le support web est activé et les fichiers générés
RUN flutter config --enable-web
RUN flutter create --platforms web .

# Builder l'application en mode release pour web
RUN flutter build web --release

# Étape de production - serveur web Nginx
FROM nginx:alpine

# Copier les fichiers build depuis l'étape précédente
COPY --from=0 /app/build/web /usr/share/nginx/html

# Créer la configuration Nginx directement
RUN echo "events {" > /etc/nginx/nginx.conf && \
    echo "    worker_connections 1024;" >> /etc/nginx/nginx.conf && \
    echo "}" >> /etc/nginx/nginx.conf && \
    echo "" >> /etc/nginx/nginx.conf && \
    echo "http {" >> /etc/nginx/nginx.conf && \
    echo "    include /etc/nginx/mime.types;" >> /etc/nginx/nginx.conf && \
    echo "    default_type application/octet-stream;" >> /etc/nginx/nginx.conf && \
    echo "" >> /etc/nginx/nginx.conf && \
    echo "    server {" >> /etc/nginx/nginx.conf && \
    echo "        listen 80;" >> /etc/nginx/nginx.conf && \
    echo "        server_name localhost;" >> /etc/nginx/nginx.conf && \
    echo "        " >> /etc/nginx/nginx.conf && \
    echo "        root /usr/share/nginx/html;" >> /etc/nginx/nginx.conf && \
    echo "        index index.html;" >> /etc/nginx/nginx.conf && \
    echo "        " >> /etc/nginx/nginx.conf && \
    echo "        location / {" >> /etc/nginx/nginx.conf && \
    echo "            try_files \$uri \$uri/ /index.html;" >> /etc/nginx/nginx.conf && \
    echo "        }" >> /etc/nginx/nginx.conf && \
    echo "        " >> /etc/nginx/nginx.conf && \
    echo "        # Configuration pour les assets" >> /etc/nginx/nginx.conf && \
    echo "        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {" >> /etc/nginx/nginx.conf && \
    echo "            expires 1y;" >> /etc/nginx/nginx.conf && \
    echo "            add_header Cache-Control \"public, immutable\";" >> /etc/nginx/nginx.conf && \
    echo "        }" >> /etc/nginx/nginx.conf && \
    echo "        " >> /etc/nginx/nginx.conf && \
    echo "        # Configuration pour l'API proxy" >> /etc/nginx/nginx.conf && \
    echo "        location /api/ {" >> /etc/nginx/nginx.conf && \
    echo "            proxy_pass http://backend:8080/;" >> /etc/nginx/nginx.conf && \
    echo "            proxy_set_header Host \$host;" >> /etc/nginx/nginx.conf && \
    echo "            proxy_set_header X-Real-IP \$remote_addr;" >> /etc/nginx/nginx.conf && \
    echo "            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;" >> /etc/nginx/nginx.conf && \
    echo "            proxy_set_header X-Forwarded-Proto \$scheme;" >> /etc/nginx/nginx.conf && \
    echo "        }" >> /etc/nginx/nginx.conf && \
    echo "        " >> /etc/nginx/nginx.conf && \
    echo "        # Gestion des erreurs" >> /etc/nginx/nginx.conf && \
    echo "        error_page 404 /index.html;" >> /etc/nginx/nginx.conf && \
    echo "        error_page 500 502 503 504 /50x.html;" >> /etc/nginx/nginx.conf && \
    echo "        location = /50x.html {" >> /etc/nginx/nginx.conf && \
    echo "            root /usr/share/nginx/html;" >> /etc/nginx/nginx.conf && \
    echo "        }" >> /etc/nginx/nginx.conf && \
    echo "    }" >> /etc/nginx/nginx.conf && \
    echo "}" >> /etc/nginx/nginx.conf

# Exposer le port 80
EXPOSE 80

# Commande pour lancer Nginx
CMD ["nginx", "-g", "daemon off;"]