#!/bin/bash

# Scout Pro - Baseball Scouting App Setup Script
# This script helps set up the complete application environment

set -e

echo "🏁 Scout Pro Setup Script"
echo "========================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are installed"

# Create project structure
echo "📁 Creating project structure..."
mkdir -p backend frontend/src frontend/public

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  IMPORTANT: Please edit .env file with your secure passwords!"
    echo "   Run: nano .env"
else
    echo "✅ .env file already exists"
fi

# Generate random passwords if they don't exist
if ! grep -q "your_secure" .env; then
    echo "🔐 .env file already configured"
else
    echo "🔐 Generating secure passwords..."
    
    # Generate random passwords (alphanumeric only to avoid sed issues)
    MONGO_PASS=$(openssl rand -hex 16)
    JWT_SECRET=$(openssl rand -hex 32)
    NPM_ROOT_PASS=$(openssl rand -hex 16)
    NPM_PASS=$(openssl rand -hex 16)
    
    # Update .env file using a safer method
    # Create a temporary file with the updated content
    cat > .env << EOF
# Environment Variables Configuration
# Generated automatically by setup script

# MongoDB Configuration
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=$MONGO_PASS

# JWT Secret (use a strong random string)
JWT_SECRET=$JWT_SECRET

# Nginx Proxy Manager Database
NPM_DB_ROOT_PASSWORD=$NPM_ROOT_PASS
NPM_DB_PASSWORD=$NPM_PASS

# Domain Configuration (update with your domain)
DOMAIN_NAME=your-domain.com

# Optional: Custom API URL for frontend (if using different domain)
# REACT_APP_API_URL=https://api.your-domain.com/api
EOF
    
    echo "✅ Generated secure passwords in .env file"
fi

# Create frontend index.html
echo "📄 Creating frontend index.html..."
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

# Create frontend index.js
echo "📄 Creating frontend index.js..."
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

# Generate package-lock.json files for better Docker builds
echo "📦 Generating package-lock.json files..."
if [ -f backend/package.json ] && [ ! -f backend/package-lock.json ]; then
    echo "   Generating backend package-lock.json..."
    cd backend && npm install --package-lock-only && cd ..
fi

if [ -f frontend/package.json ] && [ ! -f frontend/package-lock.json ]; then
    echo "   Generating frontend package-lock.json..."
    cd frontend && npm install --package-lock-only && cd ..
fi

# Check if ports are available
echo "🔍 Checking if required ports are available..."
PORTS=(80 443 81)
for port in "${PORTS[@]}"; do
    if lsof -i :$port &> /dev/null; then
        echo "⚠️  Port $port is already in use. Please stop the service using this port."
        lsof -i :$port
    else
        echo "✅ Port $port is available"
    fi
done

# Build and start services
echo "🚀 Building and starting services..."
echo "   This may take several minutes on first run..."

# Pull base images first to show progress
# docker-compose pull

# Build and start services
docker compose up -d --build

# Wait for services to be healthy
echo "⏳ Waiting for services to start..."
sleep 30

# Check service status
echo "📊 Service Status:"
docker compose ps

# Show next steps
echo ""
echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "📋 Next Steps:"
echo "1. Configure Nginx Proxy Manager:"
echo "   - Access: http://$(hostname -I | awk '{print $1}'):81"
echo "   - Default login: admin@example.com / changeme"
echo "   - ⚠️  CHANGE DEFAULT PASSWORD IMMEDIATELY!"
echo ""
echo "2. Setup Domain (if you have one):"
echo "   - Point your domain DNS to: $(hostname -I | awk '{print $1}')"
echo "   - Add proxy host in Nginx Proxy Manager"
echo "   - Request SSL certificate"
echo ""
echo "3. Access Application:"
echo "   - Local: http://$(hostname -I | awk '{print $1}'):3000"
echo "   - Demo login: coach@demo.com / password123"
echo "   - Registration code: COACH2024"
echo ""
echo "4. View Logs:"
echo "   docker compose logs -f"
echo ""
echo "5. Stop Services:"
echo "   docker compose down"
echo ""

# Show important security reminders
echo "🔒 Security Reminders:"
echo "- Change default Nginx Proxy Manager password"
echo "- Use strong passwords in .env file"
echo "- Enable SSL/HTTPS for production"
echo "- Regularly update Docker images"
echo "- Backup your database regularly"
echo ""

echo "📚 For detailed documentation, see README.md"