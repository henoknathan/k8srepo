# Stage 1: Build the React application
FROM node:18-alpine AS builder
WORKDIR /app

# Cache dependencies: Copy only package files first
COPY package*.json ./
RUN npm ci --only=production

# Copy source and build
COPY . .
RUN npm run build

# Stage 2: Serve the static files with Nginx
FROM nginx:stable-alpine

# Copy the custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the build output from the builder stage to Nginx's public folder
# Note: 'build' is the default for Create React App; use 'dist' for Vite
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port 80 for the Load Balancer
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

