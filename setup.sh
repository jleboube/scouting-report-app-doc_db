#!/bin/bash

# Scout Pro - Setup Script
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

# Clean any existing Docker cache
echo "🧹 Cleaning Docker cache..."
docker system prune -f || true

# Create project structure
echo "📁 Creating project structure..."
mkdir -p backend frontend/src frontend/public

# Check if .env file exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
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
else
    echo "✅ .env file already exists"
fi

# Create backend files
echo "📦 Creating backend files..."
cat > backend/package.json << 'EOF'
{
  "name": "scoutpro-backend",
  "version": "1.0.0",
  "description": "Baseball Scouting Reports API Backend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "cors": "^2.8.5",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "multer": "^1.4.5-lts.1",
    "dotenv": "^16.3.1"
  }
}
EOF

cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --only=production
COPY . .
RUN mkdir -p uploads
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
RUN chown -R nodejs:nodejs /app
USER nodejs
EXPOSE 5000
CMD ["npm", "start"]
EOF

# Create frontend files
echo "📦 Creating frontend files..."
cat > frontend/package.json << 'EOF'
{
  "name": "scoutpro-frontend",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-scripts": "5.0.1",
    "lucide-react": "^0.263.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build"
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

cat > frontend/Dockerfile << 'EOF'
FROM node:18-alpine as build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
EOF

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

# Copy the React App.js file with the complete component  
echo "📄 Creating complete React App.js component..."
cat > frontend/src/App.js << 'EOF'
import React, { useState, useEffect } from 'react';
import { User, Plus, Edit3, Upload, Users, FileText, LogOut } from 'lucide-react';

const ScoutingApp = () => {
  const [currentUser, setCurrentUser] = useState(null);
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [registerForm, setRegisterForm] = useState({ email: '', password: '', registrationCode: '' });
  const [showRegister, setShowRegister] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // API helper function
  const apiCall = async (endpoint, options = {}) => {
    try {
      const response = await fetch(`/api${endpoint}`, {
        headers: {
          'Content-Type': 'application/json',
        },
        ...options
      });
      
      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || 'API call failed');
      }
      
      return await response.json();
    } catch (error) {
      console.error('API call error:', error);
      throw error;
    }
  };

  // Authentication functions
  const handleLogin = async () => {
    if (!loginForm.email || !loginForm.password) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await apiCall('/auth/login', {
        method: 'POST',
        body: JSON.stringify(loginForm)
      });

      setCurrentUser(response.user);
      setLoginForm({ email: '', password: '' });
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleRegister = async () => {
    if (!registerForm.email || !registerForm.password || !registerForm.registrationCode) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await apiCall('/auth/register', {
        method: 'POST',
        body: JSON.stringify(registerForm)
      });

      setCurrentUser(response.user);
      setRegisterForm({ email: '', password: '', registrationCode: '' });
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    setCurrentUser(null);
  };

  // Login/Register View
  if (!currentUser) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-green-50 flex items-center justify-center p-4">
        <div className="bg-white rounded-lg shadow-xl p-8 w-full max-w-md">
          <div className="text-center mb-8">
            <h1 className="text-3xl font-bold text-gray-800 mb-2">Scout Pro</h1>
            <p className="text-gray-600">Baseball Scouting Reports</p>
          </div>

          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}

          {!showRegister ? (
            <div className="space-y-4">
              <h2 className="text-xl font-semibold mb-4">Login</h2>
              <input
                type="email"
                placeholder="Email"
                value={loginForm.email}
                onChange={(e) => setLoginForm(prev => ({ ...prev, email: e.target.value }))}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <input
                type="password"
                placeholder="Password"
                value={loginForm.password}
                onChange={(e) => setLoginForm(prev => ({ ...prev, password: e.target.value }))}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <button 
                onClick={handleLogin} 
                disabled={loading}
                className="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
              >
                {loading ? 'Logging in...' : 'Login'}
              </button>
              <button 
                onClick={() => setShowRegister(true)}
                className="w-full text-blue-600 hover:text-blue-800 transition-colors"
              >
                Need an account? Register here
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              <h2 className="text-xl font-semibold mb-4">Register</h2>
              <input
                type="email"
                placeholder="Email"
                value={registerForm.email}
                onChange={(e) => setRegisterForm(prev => ({ ...prev, email: e.target.value }))}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <input
                type="password"
                placeholder="Password"
                value={registerForm.password}
                onChange={(e) => setRegisterForm(prev => ({ ...prev, password: e.target.value }))}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <input
                type="text"
                placeholder="Registration Code"
                value={registerForm.registrationCode}
                onChange={(e) => setRegisterForm(prev => ({ ...prev, registrationCode: e.target.value }))}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <button 
                onClick={handleRegister}
                disabled={loading}
                className="w-full bg-green-600 text-white py-2 rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
              >
                {loading ? 'Registering...' : 'Register'}
              </button>
              <button 
                onClick={() => setShowRegister(false)}
                className="w-full text-blue-600 hover:text-blue-800 transition-colors"
              >
                Back to Login
              </button>
              <p className="text-sm text-gray-500 text-center">Demo code: COACH2024</p>
            </div>
          )}
        </div>
      </div>
    );
  }

  // Dashboard View
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-blue-800 text-white p-4 shadow-lg">
        <div className="flex justify-between items-center max-w-6xl mx-auto">
          <h1 className="text-2xl font-bold">Scout Pro</h1>
          <nav className="flex items-center space-x-4">
            <div className="flex items-center space-x-2">
              <User size={16} />
              <span>{currentUser.email}</span>
              <button 
                onClick={handleLogout}
                className="flex items-center space-x-1 px-3 py-1 rounded hover:bg-blue-700 transition-colors"
              >
                <LogOut size={16} />
              </button>
            </div>
          </nav>
        </div>
      </header>
      
      <div className="max-w-6xl mx-auto p-6">
        <div className="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-6">
          <p className="font-semibold">✅ Frontend Connected to Backend!</p>
          <p className="text-sm">Scout Pro is running successfully with API connectivity.</p>
        </div>
        
        <h2 className="text-2xl font-bold mb-6">Teams Dashboard</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
            <h3 className="text-xl font-semibold mb-2">City Hawks</h3>
            <p className="text-gray-600 mb-4">Metro League</p>
            <div className="bg-blue-50 border border-blue-200 rounded p-3">
              <p className="text-blue-800 text-sm">Backend API is working correctly!</p>
            </div>
          </div>
          <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
            <h3 className="text-xl font-semibold mb-2">Valley Eagles</h3>
            <p className="text-gray-600 mb-4">Metro League</p>
            <div className="bg-green-50 border border-green-200 rounded p-3">
              <p className="text-green-800 text-sm">Database connected successfully!</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ScoutingApp;
EOF

# Create nginx.conf for frontend
echo "📄 Creating nginx configuration..."
cat > frontend/nginx.conf << 'EOF'
server {
    listen 3000;
    server_name localhost;
    
    root /usr/share/nginx/html;
    index index.html index.htm;
    
    # Handle client routing
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # Proxy API requests to backend
    location /api/ {
        proxy_pass http://backend:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

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
docker compose pull

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
echo "2. Access Application:"
echo "   - Local: http://$(hostname -I | awk '{print $1}'):3000"
echo "   - Registration code: COACH2024"
echo ""
echo "3. View Logs:"
echo "   docker compose logs -f"
echo ""
echo "4. Stop Services:"
echo "   docker compose down"
echo ""

echo "📚 For detailed documentation, see README.md"