#Architectural Design Benefits:
#Attack Surface Reduction: By dropping Node.js and node_modules from the final 
#image, attackers cannot exploit development tools if your container is ever compromised.Minimized EKS Network 
#Overhead: This multi-stage pattern shrinks the final image from roughly 1GB down to less than 50MB. 
#This drastically speeds up your Jenkins upload times and allows AWS EKS to pull and scale your pods instantly 
#during traffic spikes.

# Stage 1: Build assets
# PURPOSE: Creates an isolated environment to safely compile the React/Vue/Angular frontend.
# DETAIL: 'AS builder' names this phase so we can copy files out of it later.
# 'node:20-alpine' uses a highly secure, stripped-down Linux distribution (Alpine) containing Node 20.
FROM node:20-alpine AS builder

# PURPOSE: Defines the default directory inside the container where all commands will run.
# DETAIL: If the /app folder does not exist, Docker creates it automatically.
WORKDIR /app

# PURPOSE: Copies dependency definition files before copying the rest of your application code.
# DETAIL: This is done first to leverage Docker's caching system. If your dependencies haven't 
# changed, Docker skips the expensive 'npm ci' execution step on future builds.
COPY package*.json ./

# PURPOSE: Installs the exact software versions specified in your package-lock.json file.
# DETAIL: 'npm ci' (Clean Install) is faster and more strict than 'npm install'. It is mandatory
# for automated Jenkins pipelines because it blocks builds if package versions mismatch.
RUN npm ci

# PURPOSE: Copies every remaining source code file from your repository into the container workspace.
# DETAIL: This transfers your frontend components, styles, and configurations for compilation.
COPY . .

# PURPOSE: Compiles the source files into minimized, production-ready HTML, CSS, and JavaScript.
# DETAIL: This outputs raw static files, typically placing them inside a folder named '/app/dist'.
RUN npm run build


# Stage 2: Production serving via Nginx
# PURPOSE: Discards the heavy Node.js engine and initializes a lightweight web server.
# DETAIL: 'nginx:1.25-alpine' is extremely small (~20MB) and highly optimized for serving static assets.
FROM nginx:1.25-alpine

# PURPOSE: Extracts only the final compiled website files from the first stage.
# DETAIL: '--from=builder' looks back at Phase 1. It grabs the static files from '/app/dist' 
# and drops them into Nginx's public web folder. The Node engine, source code, and development 
# tools are completely left behind, keeping the final image tiny and safe.
COPY --from=builder /app/dist /usr/share/nginx/html

# PURPOSE: Overwrites Nginx's default routing configuration with your custom enterprise rules.
# DETAIL: This is critical for Single Page Applications (SPAs) to handle URL path deep-linking 
# and custom security headers correctly without throwing 404 errors.
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# PURPOSE: Informs Kubernetes (and developers) that this container expects web traffic on Port 80.
# DETAIL: This maps perfectly to the 'containerPort: 80' definition inside your 'k8s/deployment.yaml'.
EXPOSE 80

# PURPOSE: Launches the Nginx web server process when the Kubernetes pod powers up.
# DETAIL: '-g "daemon off;"' forces Nginx to run in the foreground. This is mandatory for containers; 
# if Nginx runs as a background daemon, Docker will assume the process finished and immediately kill the container.
CMD ["nginx", "-g", "daemon off;"]
