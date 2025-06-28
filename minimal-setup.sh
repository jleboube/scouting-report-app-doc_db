#!/bin/bash

# Scout Pro - Minimal Setup Script
# Creates a working deployment with minimal dependencies

set -e

echo "🚀 Scout Pro Minimal Setup"
echo "=========================="

# Clean any existing Docker cache
echo "🧹 Cleaning Docker cache..."
docker system prune -f || true

# Create directory structure
echo "📁 Creating directory structure..."
rm -rf backend frontend
mkdir -p backend frontend/src frontend/public

# Create backend files
echo "📦 Creating backend files..."

cat > backend/package.json << 'EOF'
{
  "name": "scoutpro-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
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

cat > backend/server.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'default-secret-key';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://mongo:27017/scoutpro';

// Middleware
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static('uploads'));

// Create uploads directory
if (!fs.existsSync('uploads')) {
  fs.mkdirSync('uploads');
}

// MongoDB connection
mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
}).then(() => console.log('Connected to MongoDB'))
  .catch(err => console.error('MongoDB connection error:', err));

// Simple user schema
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, default: 'coach' },
  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);

// Auth routes
app.post('/api/auth/register', async (req, res) => {
  try {
    const { email, password, registrationCode } = req.body;
    
    if (registrationCode !== 'COACH2024') {
      return res.status(400).json({ message: 'Invalid registration code' });
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = new User({ email, password: hashedPassword });
    await user.save();

    const token = jwt.sign({ userId: user._id, email: user.email }, JWT_SECRET, { expiresIn: '24h' });
    res.status(201).json({ token, user: { id: user._id, email: user.email, role: user.role } });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    const token = jwt.sign({ userId: user._id, email: user.email }, JWT_SECRET, { expiresIn: '24h' });
    res.json({ token, user: { id: user._id, email: user.email, role: user.role } });
  } catch (error) {
    res.status(500).json({ message: 'Server error' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Simple route for testing
app.get('/api/teams', (req, res) => {
  res.json([
    { _id: '1', name: 'City Hawks', league: 'Metro League' },
    { _id: '2', name: 'Valley Eagles', league: 'Metro League' }
  ]);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
EOF

cat > backend/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --only=production
COPY . .
RUN mkdir -p uploads
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
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "browserslist": {
    "production": [">0.2%", "not dead", "not op_mini all"],
    "development": ["last 1 chrome version", "last 1 firefox version", "last 1 safari version"]
  }
}
EOF

cat > frontend/public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Scout Pro</title>
    <script src="https://cdn.tailwindcss.com"></script>
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
EOF

cat > frontend/src/index.js << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App />);
EOF

# Copy the React component from the artifacts
echo "📦 Creating React component..."
cat > frontend/src/App.js << 'EOF'
import React, { useState } from 'react';

function App() {
  const [user, setUser] = useState(null);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });
      
      const data = await response.json();
      if (response.ok) {
        setUser(data.user);
      } else {
        alert(data.message);
      }
    } catch (error) {
      alert('Login failed');
    }
    setLoading(false);
  };

  if (user) {
    return (
      <div className="min-h-screen bg-gray-50 p-4">
        <div className="max-w-md mx-auto bg-white rounded-lg shadow p-6">
          <h1 className="text-2xl font-bold mb-4">Scout Pro</h1>
          <p className="mb-4">Welcome, {user.email}!</p>
          <p className="text-green-600">✅ Backend connection successful!</p>
          <button 
            onClick={() => setUser(null)}
            className="mt-4 bg-red-500 text-white px-4 py-2 rounded"
          >
            Logout
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow p-6 w-full max-w-md">
        <h1 className="text-2xl font-bold mb-6">Scout Pro Login</h1>
        <div className="space-y-4">
          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full border rounded px-3 py-2"
          />
          <input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full border rounded px-3 py-2"
          />
          <button
            onClick={handleLogin}
            disabled={loading}
            className="w-full bg-blue-500 text-white py-2 rounded disabled:opacity-50"
          >
            {loading ? 'Logging in...' : 'Login'}
          </button>
          <div className="bg-blue-50 border border-blue-200 rounded p-3 text-sm">
            <strong>Demo:</strong> Create account with registration code: COACH2024
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
EOF

cat > frontend/nginx.conf << 'EOF'
server {
    listen 3000;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    location /api/ {
        proxy_pass http://backend:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
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

# Create environment file
echo "🔐 Creating environment file..."
MONGO_PASS=$(openssl rand -hex 16)
JWT_SECRET=$(openssl rand -hex 32)

cat > .env << EOF
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=$MONGO_PASS
JWT_SECRET=$JWT_SECRET
MONGODB_URI=mongodb://mongo:27017/scoutpro
EOF

# Create simple docker-compose
echo "🐳 Creating Docker Compose configuration..."
cat > docker-compose.minimal.yml << 'EOF'
version: '3.8'

services:
  mongo:
    image: mongo:7.0
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USERNAME}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
    volumes:
      - mongo_data:/data/db
    networks:
      - app-network

  backend:
    build: ./backend
    environment:
      MONGODB_URI: mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@mongo:27017/scoutpro?authSource=admin
      JWT_SECRET: ${JWT_SECRET}
    ports:
      - "5000:5000"
    depends_on:
      - mongo
    networks:
      - app-network

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    depends_on:
      - backend
    networks:
      - app-network

volumes:
  mongo_data:

networks:
  app-network:
    driver: bridge
EOF

echo "🚀 Building and starting services..."
docker-compose -f docker-compose.minimal.yml up -d --build

echo "⏳ Waiting for services..."
sleep 30

echo ""
echo "🎉 Minimal Setup Complete!"
echo "========================="
echo ""
echo "🌐 Access your app:"
echo "- Frontend: http://localhost:3000"
echo "- Backend API: http://localhost:5000/api/health"
echo ""
echo "🔑 To test:"
echo "1. Go to http://localhost:3000"
echo "2. Click register or create account"
echo "3. Use registration code: COACH2024"
echo ""
echo "📊 Check status: docker-compose -f docker-compose.minimal.yml ps"
echo "📝 View logs: docker-compose -f docker-compose.minimal.yml logs -f"
echo "🛑 Stop: docker-compose -f docker-compose.minimal.yml down"
EOF