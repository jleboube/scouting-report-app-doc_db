const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');

// Rate limiting configuration
const createRateLimiter = (windowMs, max, message) => {
  return rateLimit({
    windowMs,
    max,
    message: { error: message },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      res.status(429).json({
        error: message,
        retryAfter: Math.round(windowMs / 1000)
      });
    }
  });
};

// Different rate limits for different endpoints
const rateLimiters = {
  // General API rate limit
  general: createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    100, // requests per window
    'Too many requests, please try again later'
  ),

  // Authentication rate limit (stricter)
  auth: createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    5, // requests per window
    'Too many authentication attempts, please try again later'
  ),

  // File upload rate limit
  upload: createRateLimiter(
    60 * 60 * 1000, // 1 hour
    10, // uploads per hour
    'Too many file uploads, please try again later'
  ),

  // Registration rate limit (very strict)
  register: createRateLimiter(
    24 * 60 * 60 * 1000, // 24 hours
    3, // registrations per day per IP
    'Too many registration attempts, please try again tomorrow'
  )
};

// Security middleware
const securityMiddleware = () => {
  return helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'", "https://cdn.tailwindcss.com"],
        scriptSrc: ["'self'", "https://cdn.tailwindcss.com"],
        imgSrc: ["'self'", "data:", "blob:"],
        connectSrc: ["'self'"],
        fontSrc: ["'self'"],
        objectSrc: ["'none'"],
        mediaSrc: ["'self'"],
        frameSrc: ["'none'"],
      },
    },
    crossOriginEmbedderPolicy: false,
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true
    },
    noSniff: true,
    frameguard: { action: 'deny' },
    xssFilter: true,
    referrerPolicy: { policy: 'same-origin' }
  });
};

// Compression middleware
const compressionMiddleware = () => {
  return compression({
    filter: (req, res) => {
      if (req.headers['x-no-compression']) {
        return false;
      }
      return compression.filter(req, res);
    },
    threshold: 1024,
    level: 6
  });
};

// Logging middleware
const loggingMiddleware = () => {
  const format = process.env.NODE_ENV === 'production' ? 'combined' : 'dev';
  return morgan(format, {
    skip: (req, res) => {
      // Skip health check logs in production
      return req.path === '/api/health' && process.env.NODE_ENV === 'production';
    }
  });
};

// Request timeout middleware
const timeoutMiddleware = (timeout = 30000) => {
  return (req, res, next) => {
    res.setTimeout(timeout, () => {
      res.status(408).json({ error: 'Request timeout' });
    });
    next();
  };
};

// Request size limiting middleware
const requestSizeMiddleware = () => {
  return (req, res, next) => {
    // Set different limits based on endpoint
    if (req.path.includes('/upload')) {
      req.rawBody = Buffer.alloc(0);
      req.on('data', chunk => {
        req.rawBody = Buffer.concat([req.rawBody, chunk]);
        if (req.rawBody.length > 10 * 1024 * 1024) { // 10MB limit for uploads
          res.status(413).json({ error: 'File too large' });
          return;
        }
      });
    }
    next();
  };
};

// Error handling middleware
const errorHandlingMiddleware = () => {
  return (err, req, res, next) => {
    console.error('Error:', err);

    // Rate limit error
    if (err.status === 429) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        retryAfter: err.retryAfter
      });
    }

    // Multer errors
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large' });
    }

    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({ error: 'Too many files' });
    }

    if (err.code === 'LIMIT_UNEXPECTED_FILE') {
      return res.status(400).json({ error: 'Unexpected file field' });
    }

    // MongoDB errors
    if (err.name === 'ValidationError') {
      return res.status(400).json({
        error: 'Validation error',
        details: Object.values(err.errors).map(e => e.message)
      });
    }

    if (err.code === 11000) {
      return res.status(400).json({ error: 'Duplicate entry' });
    }

    // JWT errors
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({ error: 'Invalid token' });
    }

    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: 'Token expired' });
    }

    // Default error
    res.status(err.status || 500).json({
      error: process.env.NODE_ENV === 'production' 
        ? 'Internal server error' 
        : err.message
    });
  };
};

// Health check middleware with detailed status
const healthCheckMiddleware = () => {
  return async (req, res) => {
    const health = {
      status: 'OK',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      environment: process.env.NODE_ENV,
      version: process.env.npm_package_version || '1.0.0',
      memory: process.memoryUsage(),
      cpu: process.cpuUsage()
    };

    // Check database connection
    try {
      const mongoose = require('mongoose');
      if (mongoose.connection.readyState === 1) {
        health.database = 'connected';
      } else {
        health.database = 'disconnected';
        health.status = 'ERROR';
      }
    } catch (error) {
      health.database = 'error';
      health.status = 'ERROR';
    }

    // Check disk space for uploads
    try {
      const fs = require('fs');
      const stats = fs.statSync('./uploads');
      health.uploadsDirectory = 'accessible';
    } catch (error) {
      health.uploadsDirectory = 'error';
      health.status = 'WARNING';
    }

    const statusCode = health.status === 'OK' ? 200 : 
                      health.status === 'WARNING' ? 200 : 503;

    res.status(statusCode).json(health);
  };
};

// CORS middleware with environment-specific settings
const corsMiddleware = () => {
  const cors = require('cors');
  
  return cors({
    origin: (origin, callback) => {
      // Allow requests with no origin (mobile apps, etc.)
      if (!origin) return callback(null, true);

      const allowedOrigins = process.env.NODE_ENV === 'production'
        ? [
            process.env.FRONTEND_URL,
            process.env.DOMAIN_NAME && `https://${process.env.DOMAIN_NAME}`,
            process.env.DOMAIN_NAME && `http://${process.env.DOMAIN_NAME}`
          ].filter(Boolean)
        : ['http://localhost:3000', 'http://localhost:3001'];

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    maxAge: 86400 // 24 hours
  });
};

module.exports = {
  rateLimiters,
  securityMiddleware,
  compressionMiddleware,
  loggingMiddleware,
  timeoutMiddleware,
  requestSizeMiddleware,
  errorHandlingMiddleware,
  healthCheckMiddleware,
  corsMiddleware
};