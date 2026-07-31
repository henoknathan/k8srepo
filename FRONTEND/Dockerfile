# Stage 1: Production serving via Nginx
# PURPOSE: Initializes a lightweight, secure web server.
# DETAIL: 'nginx:1.25-alpine' is extremely small (~20MB) and optimized for serving static assets.
FROM nginx:1.25-alpine

# PURPOSE: Defines the working directory inside the Nginx container image.
WORKDIR /usr/share/nginx/html

# PURPOSE: Copies your pure static website files directly into Nginx's public web folder.
# DETAIL: This transfers your 'index.html' (and any local assets/CSS/JS files) directly into 
# the serving path, completely bypassing the need for a heavy Node.js build step.
COPY . .

# PURPOSE: Overwrites Nginx's default routing configuration with your custom enterprise rules.
# DETAIL: This is critical for mapping your internal cluster reverse proxy '/api/' endpoints 
# and handling your static asset caching configurations safely.
COPY nginx.conf /etc/nginx/nginx.conf

# PURPOSE: Informs Kubernetes (and developers) that this container expects web traffic on Port 80.
# DETAIL: This maps perfectly to the 'containerPort: 80' definition inside your 'k8s/deployment.yaml'.
EXPOSE 80

# PURPOSE: Launches the Nginx web server process when the Kubernetes pod powers up.
# DETAIL: '-g "daemon off;"' forces Nginx to run in the foreground. This is mandatory for containers; 
# if Nginx runs as a background daemon, Docker will assume the process finished and immediately kill the container.
CMD ["nginx", "-g", "daemon off;"]


