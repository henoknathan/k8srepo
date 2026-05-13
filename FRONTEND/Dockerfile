FROM nginx:alpine

# 1. Copy your custom Nginx routing configuration file
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 2. Copy your index.html directly into Nginx's public serving folder
COPY index.html /usr/share/nginx/html/index.html

