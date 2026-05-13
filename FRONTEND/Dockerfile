# ... (Your previous base image setup, e.g., FROM node:alpine)
# STAGE 1: Build the static application files
FROM node:18-alpine AS build
WORKDIR /app

# Copy dependency mappings
COPY package*.json ./

# Execute production install with standard fallback tracking
RUN npm ci --omit=dev || npm install --production

# Copy remaining static web assets
COPY . .

# STAGE 2: Serve the files using your Nginx configuration
FROM nginx:alpine
COPY --from=build /app /usr/share/nginx/html

WORKDIR /app

# 1. Copy package files (Using a wildcard allows it to build even if lock file is missing)
COPY package*.json ./

# 2. CHANGED: Swapped deprecated flag for the modern production install flag
RUN npm ci --omit=dev || npm install --production

# 3. Copy the rest of your frontend source files
COPY . .

# ... (The rest of your Nginx build/copy steps)

