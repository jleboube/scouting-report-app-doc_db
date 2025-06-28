# Frontend Dockerfile - Simplified
FROM node:18-alpine as build

WORKDIR /app

# Copy package.json
COPY package.json ./

# Install dependencies using npm install (not npm ci)
RUN npm install

# Copy source code
COPY . .

# Build the app
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built app from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]