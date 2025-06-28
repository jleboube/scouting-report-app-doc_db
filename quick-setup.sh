#!/bin/bash

# Scout Pro - Quick Setup Script
# Simplified setup without package-lock.json generation

set -e

echo "🚀 Scout Pro Quick Setup"
echo "========================"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p backend frontend/src frontend/public

# Create .env file with secure passwords
echo "🔐 Creating .env file with secure passwords..."
MONGO_PASS=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)
NPM_ROOT_PASS=$(openssl rand -hex 16)
NPM_PASS=$(openssl rand -hex 16)

cat > .env << EOF
# Environment Variables Configuration
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=$MONGO_PASS
JWT_SECRET=$JWT_SECRET
NPM_DB_ROOT_PASSWORD=$NPM_ROOT_PASS
NPM_DB_PASSWORD=$NPM_PASS
DOMAIN_NAME=your-domain.com
EOF

echo "✅ Generated secure passwords in .env file"

# Create essential frontend files
echo "📄 Creating frontend files..."

cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Baseball Scouting Reports Application" />
    <title>Scout Pro - Baseball Scouting Reports</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOF

cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

# Create a simplified docker-compose for quick deployment
echo "🐳 Creating simplified Docker Compose configuration..."
cat > docker-compose.quick.yml << 'EOF'
version: '3.8'

services:
  mongo:
    image: mongo:7.0
    container_name: scoutpro-mongo
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USERNAME:-admin}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD:-password}
      MONGO_INITDB_DATABASE: scoutpro
    volumes:
      - mongo_data:/data/db
      - ./mongo-init.js:/docker-entrypoint-initdb.d/mongo-init.js:ro
    networks:
      - scoutpro-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost:27017/test --quiet
      interval: 30s
      timeout: 10s
      retries: 3

  backend:
    build: 
      context: ./backend
      dockerfile: Dockerfile
    container_name: scoutpro-backend
    restart: unless-stopped
    environment:
      NODE_ENV: production
      PORT: 5000
      MONGODB_URI: mongodb://mongo:27017/scoutpro
      JWT_SECRET: ${JWT_SECRET:-your-secret-key}
    volumes:
      - backend_uploads:/app/uploads
    ports:
      - "5000:5000"
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - scoutpro-network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: scoutpro-frontend
    restart: unless-stopped
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - scoutpro-network

  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: scoutpro-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    environment:
      DB_MYSQL_HOST: "proxy-db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: ${NPM_DB_PASSWORD:-npm_password}
      DB_MYSQL_NAME: "npm"
    volumes:
      - nginx_data:/data
      - nginx_letsencrypt:/etc/letsencrypt
    depends_on:
      - proxy-db
    networks:
      - scoutpro-network
      - proxy-network

  proxy-db:
    image: 'jc21/mariadb-aria:latest'
    container_name: scoutpro-proxy-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${NPM_DB_ROOT_PASSWORD:-npm_root_password}
      MYSQL_DATABASE: npm
      MYSQL_USER: npm
      MYSQL_PASSWORD: ${NPM_DB_PASSWORD:-npm_password}
    volumes:
      - proxy_db_data:/var/lib/mysql
    networks:
      - proxy-network

volumes:
  mongo_data:
  backend_uploads:
  nginx_data:
  nginx_letsencrypt:
  proxy_db_data:

networks:
  scoutpro-network:
    driver: bridge
  proxy-network:
    driver: bridge
EOF

echo "🚀 Starting services with quick configuration..."
docker compose -f docker-compose.quick.yml up -d --build

echo "⏳ Waiting for services to start..."
sleep 60

# Check service status
echo "📊 Service Status:"
docker compose -f docker-compose.quick.yml ps

echo ""
echo "🎉 Quick Setup Complete!"
echo "======================="
echo ""
echo "📋 Access Points:"
echo "- Frontend: http://$(hostname -I | awk '{print $1}'):3000"
echo "- Backend API: http://$(hostname -I | awk '{print $1}'):5000/api/health"
echo "- Nginx Proxy Manager: http://$(hostname -I | awk '{print $1}'):81"
echo ""
echo "🔑 Demo Login:"
echo "- Email: coach@demo.com"
echo "- Password: password123"
echo "- Registration code: COACH2024"
echo ""
echo "⚙️  Nginx Proxy Manager Setup:"
echo "- Default login: admin@example.com / changeme"
echo "- Add proxy host: frontend:3000"
echo "- Request SSL certificate for your domain"
echo ""
echo "📊 View logs: docker compose -f docker-compose.quick.yml logs -f"
echo "🛑 Stop services: docker compose -f docker-compose.quick.yml down"