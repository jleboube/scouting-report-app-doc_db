const express = require('express');
const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

// Import middleware
const {
  rateLimiters,
  securityMiddleware,
  compressionMiddleware,
  loggingMiddleware,
  timeoutMiddleware,
  requestSizeMiddleware,
  errorHandlingMiddleware,
  healthCheckMiddleware,
  corsMiddleware
} = require('./middleware');

const app = express();
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://mongo:27017/scoutpro';

// Apply middleware in order
app.use(loggingMiddleware());
app.use(securityMiddleware());
app.use(compressionMiddleware());
app.use(timeoutMiddleware());
app.use(corsMiddleware());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use('/uploads', express.static('uploads'));
app.use(requestSizeMiddleware());

// Create uploads directory if it doesn't exist
if (!fs.existsSync('uploads')) {
  fs.mkdirSync('uploads');
}

// MongoDB connection
mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => console.log('Connected to MongoDB'))
.catch(err => console.error('MongoDB connection error:', err));

// Database Schemas
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, default: 'coach' },
  createdAt: { type: Date, default: Date.now }
});

const teamSchema = new mongoose.Schema({
  name: { type: String, required: true },
  league: { type: String, required: true },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  createdAt: { type: Date, default: Date.now }
});

const playerSchema = new mongoose.Schema({
  name: { type: String, required: true },
  position: { type: String, required: true },
  jerseyNumber: { type: String, required: true },
  teamId: { type: mongoose.Schema.Types.ObjectId, ref: 'Team', required: true },
  createdAt: { type: Date, default: Date.now }
});

const reportSchema = new mongoose.Schema({
  playerId: { type: mongoose.Schema.Types.ObjectId, ref: 'Player', required: true },
  scoutId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  date: { type: Date, required: true },
  evaluations: { type: Map, of: String },
  notes: { type: String },
  sprayChartUrl: { type: String },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

// Models
const User = mongoose.model('User', userSchema);
const Team = mongoose.model('Team', teamSchema);
const Player = mongoose.model('Player', playerSchema);
const Report = mongoose.model('Report', reportSchema);

// Multer configuration for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, 'spray-chart-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

// JWT middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ message: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ message: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Apply general rate limiting to all API routes
app.use('/api', rateLimiters.general);

// Auth Routes
app.post('/api/auth/register', rateLimiters.register, async (req, res) => {
  try {
    const { email, password, registrationCode } = req.body;

    // Simple registration code check
    if (registrationCode !== 'COACH2024') {
      return res.status(400).json({ message: 'Invalid registration code' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'User already exists' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password, salt);

    // Create user
    const user = new User({
      email,
      password: hashedPassword
    });

    await user.save();

    // Generate token
    const token = jwt.sign(
      { userId: user._id, email: user.email },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      message: 'User created successfully',
      token,
      user: { id: user._id, email: user.email, role: user.role }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/auth/login', rateLimiters.auth, async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ message: 'Invalid credentials' });
    }

    // Generate token
    const token = jwt.sign(
      { userId: user._id, email: user.email },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: { id: user._id, email: user.email, role: user.role }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Team Routes
app.get('/api/teams', authenticateToken, async (req, res) => {
  try {
    const teams = await Team.find().populate('createdBy', 'email');
    res.json(teams);
  } catch (error) {
    console.error('Get teams error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/teams', authenticateToken, async (req, res) => {
  try {
    const { name, league } = req.body;
    
    const team = new Team({
      name,
      league,
      createdBy: req.user.userId
    });

    await team.save();
    res.status(201).json(team);
  } catch (error) {
    console.error('Create team error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.put('/api/teams/:id', authenticateToken, async (req, res) => {
  try {
    const { name, league } = req.body;
    
    const team = await Team.findByIdAndUpdate(
      req.params.id,
      { name, league },
      { new: true }
    );

    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    res.json(team);
  } catch (error) {
    console.error('Update team error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.delete('/api/teams/:id', authenticateToken, async (req, res) => {
  try {
    const team = await Team.findByIdAndDelete(req.params.id);
    
    if (!team) {
      return res.status(404).json({ message: 'Team not found' });
    }

    // Also delete associated players and reports
    const players = await Player.find({ teamId: req.params.id });
    const playerIds = players.map(p => p._id);
    
    await Player.deleteMany({ teamId: req.params.id });
    await Report.deleteMany({ playerId: { $in: playerIds } });

    res.json({ message: 'Team and associated data deleted successfully' });
  } catch (error) {
    console.error('Delete team error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Player Routes
app.get('/api/players', authenticateToken, async (req, res) => {
  try {
    const { teamId } = req.query;
    const filter = teamId ? { teamId } : {};
    
    const players = await Player.find(filter).populate('teamId', 'name league');
    res.json(players);
  } catch (error) {
    console.error('Get players error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/players', authenticateToken, async (req, res) => {
  try {
    const { name, position, jerseyNumber, teamId } = req.body;
    
    const player = new Player({
      name,
      position,
      jerseyNumber,
      teamId
    });

    await player.save();
    await player.populate('teamId', 'name league');
    res.status(201).json(player);
  } catch (error) {
    console.error('Create player error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.put('/api/players/:id', authenticateToken, async (req, res) => {
  try {
    const { name, position, jerseyNumber, teamId } = req.body;
    
    const player = await Player.findByIdAndUpdate(
      req.params.id,
      { name, position, jerseyNumber, teamId },
      { new: true }
    ).populate('teamId', 'name league');

    if (!player) {
      return res.status(404).json({ message: 'Player not found' });
    }

    res.json(player);
  } catch (error) {
    console.error('Update player error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.delete('/api/players/:id', authenticateToken, async (req, res) => {
  try {
    const player = await Player.findByIdAndDelete(req.params.id);
    
    if (!player) {
      return res.status(404).json({ message: 'Player not found' });
    }

    // Also delete associated reports
    await Report.deleteMany({ playerId: req.params.id });

    res.json({ message: 'Player and associated reports deleted successfully' });
  } catch (error) {
    console.error('Delete player error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Report Routes
app.get('/api/reports', authenticateToken, async (req, res) => {
  try {
    const { playerId } = req.query;
    const filter = playerId ? { playerId } : {};
    
    const reports = await Report.find(filter)
      .populate('playerId', 'name position jerseyNumber')
      .populate('scoutId', 'email')
      .sort({ date: -1 });
    
    res.json(reports);
  } catch (error) {
    console.error('Get reports error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.post('/api/reports', authenticateToken, async (req, res) => {
  try {
    const { playerId, date, evaluations, notes } = req.body;
    
    const report = new Report({
      playerId,
      scoutId: req.user.userId,
      date,
      evaluations,
      notes
    });

    await report.save();
    await report.populate('playerId', 'name position jerseyNumber');
    await report.populate('scoutId', 'email');
    
    res.status(201).json(report);
  } catch (error) {
    console.error('Create report error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.put('/api/reports/:id', authenticateToken, async (req, res) => {
  try {
    const { date, evaluations, notes } = req.body;
    
    const report = await Report.findByIdAndUpdate(
      req.params.id,
      { date, evaluations, notes, updatedAt: Date.now() },
      { new: true }
    ).populate('playerId', 'name position jerseyNumber')
     .populate('scoutId', 'email');

    if (!report) {
      return res.status(404).json({ message: 'Report not found' });
    }

    res.json(report);
  } catch (error) {
    console.error('Update report error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

app.delete('/api/reports/:id', authenticateToken, async (req, res) => {
  try {
    const report = await Report.findByIdAndDelete(req.params.id);
    
    if (!report) {
      return res.status(404).json({ message: 'Report not found' });
    }

    // Delete associated spray chart file if exists
    if (report.sprayChartUrl) {
      const filename = path.basename(report.sprayChartUrl);
      const filepath = path.join('uploads', filename);
      if (fs.existsSync(filepath)) {
        fs.unlinkSync(filepath);
      }
    }

    res.json({ message: 'Report deleted successfully' });
  } catch (error) {
    console.error('Delete report error:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// File Upload Route
app.post('/api/upload/spray-chart/:reportId', rateLimiters.upload, authenticateToken, upload.single('sprayChart'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    const reportId = req.params.reportId;
    const sprayChartUrl = `/uploads/${req.file.filename}`;

    // Update report with spray chart URL
    const report = await Report.findByIdAndUpdate(
      reportId,
      { sprayChartUrl, updatedAt: Date.now() },
      { new: true }
    );

    if (!report) {
      // Delete uploaded file if report not found
      fs.unlinkSync(req.file.path);
      return res.status(404).json({ message: 'Report not found' });
    }

    res.json({ 
      message: 'Spray chart uploaded successfully',
      sprayChartUrl 
    });
  } catch (error) {
    console.error('Upload error:', error);
    
    // Clean up uploaded file on error
    if (req.file) {
      fs.unlinkSync(req.file.path);
    }
    
    res.status(500).json({ message: 'Server error' });
  }
});

// Health check route
app.get('/api/health', healthCheckMiddleware());

// Error handling middleware (must be last)
app.use(errorHandlingMiddleware());

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`MongoDB URI: ${MONGODB_URI}`);
});

module.exports = app;