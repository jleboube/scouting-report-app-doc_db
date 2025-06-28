# Scout Pro - Baseball Scouting Reports

A comprehensive web application for baseball coaches to create, edit, and manage scouting reports on players with team organization and spray chart uploads.

## Features

- 🔐 **Secure Authentication** - Email/password login with registration codes
- 👥 **Team Management** - Organize players by teams and leagues
- 📊 **Comprehensive Scouting** - Detailed evaluation categories (Hitting, Fielding, Running, Pitching)
- 📸 **Spray Chart Uploads** - Visual hitting pattern analysis
- 📱 **Responsive Design** - Works on desktop, tablet, and mobile
- 🐳 **Docker Deployment** - Easy deployment with Docker Compose
- 🌐 **Domain Support** - Nginx Proxy Manager for custom domains and SSL

## Tech Stack

### Frontend
- React 18
- Tailwind CSS
- Lucide React Icons
- Nginx (Production)

### Backend
- Node.js with Express
- MongoDB with Mongoose
- JWT Authentication
- Multer for file uploads
- bcrypt for password hashing

### Infrastructure
- Docker & Docker Compose
- Nginx Proxy Manager
- MongoDB
- Let's Encrypt SSL (via Nginx Proxy Manager)

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Domain name pointed to your server (optional but recommended)
- Ports 80, 443, and 81 available

### 1. Clone and Setup

```bash
# Create project directory structure
mkdir scoutpro-app
cd scoutpro-app

# Create backend directory and files
mkdir backend
# Copy backend files: server.js, package.json, Dockerfile

# Create frontend directory and files  
mkdir frontend
mkdir frontend/src
# Copy frontend files: App.js (from React component), package.json, Dockerfile, nginx.conf

# Copy docker-compose.yml, .env.example, mongo-init.js to root directory
```

### 2. Environment Configuration

```bash
# Copy and edit environment variables
cp .env.example .env
nano .env
```

Update the `.env` file with secure passwords:

```env
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=your_secure_mongo_password_here
JWT_SECRET=your_super_secret_jwt_key_minimum_64_characters_for_security
NPM_DB_ROOT_PASSWORD=your_secure_npm_root_password_here
NPM_DB_PASSWORD=your_secure_npm_password_here
DOMAIN_NAME=your-domain.com
```

### 3. Deploy with Docker Compose

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### 4. Setup Nginx Proxy Manager

1. Access Nginx Proxy Manager admin UI: `http://your-server-ip:81`

2. Default login credentials:
   - Email: `admin@example.com`
   - Password: `changeme`

3. **IMPORTANT**: Change default credentials immediately!

4. Add Proxy Host for your domain:
   - **Domain Names**: `your-domain.com`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `frontend`
   - **Forward Port**: `3000`
   - **Cache Assets**: ✓
   - **Block Common Exploits**: ✓
   - **Websockets Support**: ✓

5. Add API proxy (if using subdomain):
   - **Domain Names**: `api.your-domain.com`
   - **Scheme**: `http`
   - **Forward Hostname/IP**: `backend`
   - **Forward Port**: `5000`

6. Request SSL Certificate:
   - Go to SSL Certificates tab
   - Click "Add SSL Certificate"
   - Select "Let's Encrypt"
   - Enter your domain and email
   - Enable "Use a DNS Challenge" if needed

### 5. Application Access

- **Main App**: `https://your-domain.com`
- **Demo Login**: `coach@demo.com` / `password123`
- **Registration Code**: `COACH2024`
- **Proxy Manager**: `http://your-server-ip:81`

## Directory Structure

```
scoutpro-app/
├── docker-compose.yml
├── .env
├── .env.example
├── mongo-init.js
├── README.md
├── backend/
│   ├── server.js
│   ├── package.json
│   ├── Dockerfile
│   └── uploads/ (created automatically)
└── frontend/
    ├── src/
    │   └── App.js
    ├── public/
    │   └── index.html
    ├── package.json
    ├── Dockerfile
    └── nginx.conf
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login

### Teams
- `GET /api/teams` - Get all teams
- `POST /api/teams` - Create team
- `PUT /api/teams/:id` - Update team
- `DELETE /api/teams/:id` - Delete team

### Players
- `GET /api/players?teamId=:id` - Get players by team
- `POST /api/players` - Create player
- `PUT /api/players/:id` - Update player
- `DELETE /api/players/:id` - Delete player

### Reports
- `GET /api/reports?playerId=:id` - Get reports by player
- `POST /api/reports` - Create report
- `PUT /api/reports/:id` - Update report
- `DELETE /api/reports/:id` - Delete report

### File Upload
- `POST /api/upload/spray-chart/:reportId` - Upload spray chart

## Configuration Options

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MONGO_ROOT_USERNAME` | MongoDB root username | `admin` |
| `MONGO_ROOT_PASSWORD` | MongoDB root password | Required |
| `JWT_SECRET` | JWT signing secret | Required |
| `NPM_DB_PASSWORD` | Proxy manager DB password | Required |
| `DOMAIN_NAME` | Your domain name | Optional |

### Frontend Configuration

Update `frontend/src/App.js` if using different API URL:

```javascript
const API_BASE_URL = process.env.REACT_APP_API_URL || 'https://api.your-domain.com/api';
```

## Security Features

- 🔒 **Password Hashing** - bcrypt with salt rounds
- 🎟️ **JWT Tokens** - Secure session management
- 🛡️ **Input Validation** - MongoDB schema validation
- 🔐 **HTTPS** - SSL/TLS encryption via Let's Encrypt
- 🚫 **CORS Protection** - Configured for security
- 👤 **Non-root Containers** - Security hardened Docker images

## Monitoring & Maintenance

### Health Checks

All services include health checks:

```bash
# Check service health
docker-compose ps

# View specific service logs
docker-compose logs backend
docker-compose logs frontend
docker-compose logs mongo
```

### Backup Database

```bash
# Backup MongoDB
docker-compose exec mongo mongodump --out /data/backup

# Copy backup to host
docker cp scoutpro-mongo:/data/backup ./mongodb-backup
```

### Update Application

```bash
# Pull latest changes
git pull

# Rebuild and restart services
docker-compose down
docker-compose up -d --build
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if ports are in use
   netstat -tulpn | grep -E ':(80|443|81|27017|5000|3000)'
   ```

2. **Permission Issues**
   ```bash
   # Fix Docker permissions
   sudo chown -R $USER:$USER ./
   ```

3. **Container Won't Start**
   ```bash
   # Check logs
   docker-compose logs [service-name]
   
   # Restart specific service
   docker-compose restart [service-name]
   ```

4. **Database Connection Issues**
   ```bash
   # Check MongoDB logs
   docker-compose logs mongo
   
   # Verify network connectivity
   docker-compose exec backend ping mongo
   ```

### Performance Tuning

1. **MongoDB Optimization**
   - Add more indexes for large datasets
   - Configure MongoDB memory settings
   - Use MongoDB Atlas for production

2. **Frontend Optimization**
   - Enable Nginx gzip compression (already configured)
   - Add CDN for static assets
   - Implement service workers for caching

## Development

### Local Development

```bash
# Install dependencies
cd backend && npm install
cd ../frontend && npm install

# Start backend
cd backend && npm run dev

# Start frontend
cd frontend && npm start
```

### Testing

```bash
# Run backend tests
cd backend && npm test

# Run frontend tests
cd frontend && npm test
```

## License

MIT License - see LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Docker and service logs
3. Ensure all environment variables are set correctly
4. Verify domain DNS settings point to your server

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request