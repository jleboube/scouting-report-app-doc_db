// MongoDB Initialization Script
// This script runs when MongoDB container starts for the first time

// Switch to the scoutpro database
db = db.getSiblingDB('scoutpro');

// Create collections with validation
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['email', 'password', 'role'],
      properties: {
        email: {
          bsonType: 'string',
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
          description: 'must be a valid email address'
        },
        password: {
          bsonType: 'string',
          minLength: 6,
          description: 'must be a string with minimum 6 characters'
        },
        role: {
          bsonType: 'string',
          enum: ['coach', 'admin'],
          description: 'must be either coach or admin'
        },
        createdAt: {
          bsonType: 'date',
          description: 'must be a date'
        }
      }
    }
  }
});

db.createCollection('teams', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name', 'league'],
      properties: {
        name: {
          bsonType: 'string',
          minLength: 1,
          description: 'must be a non-empty string'
        },
        league: {
          bsonType: 'string',
          minLength: 1,
          description: 'must be a non-empty string'
        },
        createdBy: {
          bsonType: 'objectId',
          description: 'must be a valid ObjectId'
        },
        createdAt: {
          bsonType: 'date',
          description: 'must be a date'
        }
      }
    }
  }
});

db.createCollection('players', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name', 'position', 'jerseyNumber', 'teamId'],
      properties: {
        name: {
          bsonType: 'string',
          minLength: 1,
          description: 'must be a non-empty string'
        },
        position: {
          bsonType: 'string',
          minLength: 1,
          description: 'must be a non-empty string'
        },
        jerseyNumber: {
          bsonType: 'string',
          minLength: 1,
          description: 'must be a non-empty string'
        },
        teamId: {
          bsonType: 'objectId',
          description: 'must be a valid ObjectId'
        },
        createdAt: {
          bsonType: 'date',
          description: 'must be a date'
        }
      }
    }
  }
});

db.createCollection('reports', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['playerId', 'scoutId', 'date'],
      properties: {
        playerId: {
          bsonType: 'objectId',
          description: 'must be a valid ObjectId'
        },
        scoutId: {
          bsonType: 'objectId',
          description: 'must be a valid ObjectId'
        },
        date: {
          bsonType: 'date',
          description: 'must be a date'
        },
        evaluations: {
          bsonType: 'object',
          description: 'must be an object'
        },
        notes: {
          bsonType: 'string',
          description: 'must be a string'
        },
        sprayChartUrl: {
          bsonType: 'string',
          description: 'must be a string'
        },
        createdAt: {
          bsonType: 'date',
          description: 'must be a date'
        },
        updatedAt: {
          bsonType: 'date',
          description: 'must be a date'
        }
      }
    }
  }
});

// Create indexes for better performance
db.users.createIndex({ email: 1 }, { unique: true });
db.teams.createIndex({ name: 1 });
db.teams.createIndex({ createdBy: 1 });
db.players.createIndex({ teamId: 1 });
db.players.createIndex({ name: 1 });
db.reports.createIndex({ playerId: 1 });
db.reports.createIndex({ scoutId: 1 });
db.reports.createIndex({ date: -1 });
db.reports.createIndex({ playerId: 1, date: -1 });

// Insert sample data for demonstration
// Note: In production, remove this section

// Create a sample user (password: "password123")
const sampleUserId = new ObjectId();
db.users.insertOne({
  _id: sampleUserId,
  email: 'coach@demo.com',
  password: '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', // bcrypt hash of "password123"
  role: 'coach',
  createdAt: new Date()
});

// Create sample teams
const team1Id = new ObjectId();
const team2Id = new ObjectId();

db.teams.insertMany([
  {
    _id: team1Id,
    name: 'City Hawks',
    league: 'Metro League',
    createdBy: sampleUserId,
    createdAt: new Date()
  },
  {
    _id: team2Id,
    name: 'Valley Eagles',
    league: 'Metro League',
    createdBy: sampleUserId,
    createdAt: new Date()
  }
]);

// Create sample players
const player1Id = new ObjectId();
const player2Id = new ObjectId();
const player3Id = new ObjectId();

db.players.insertMany([
  {
    _id: player1Id,
    name: 'Mike Johnson',
    position: 'SS',
    jerseyNumber: '12',
    teamId: team1Id,
    createdAt: new Date()
  },
  {
    _id: player2Id,
    name: 'Alex Rodriguez',
    position: 'CF',
    jerseyNumber: '7',
    teamId: team1Id,
    createdAt: new Date()
  },
  {
    _id: player3Id,
    name: 'Sam Williams',
    position: '3B',
    jerseyNumber: '15',
    teamId: team2Id,
    createdAt: new Date()
  }
]);

// Create a sample scouting report
db.reports.insertOne({
  playerId: player1Id,
  scoutId: sampleUserId,
  date: new Date(),
  evaluations: {
    'hitting_contactAbility': 'Above Average',
    'hitting_power': 'Average',
    'fielding_hands': 'Excellent',
    'fielding_range': 'Above Average',
    'running_speed': 'Average'
  },
  notes: 'Strong defensive player with good contact skills. Shows potential for improvement in power hitting.',
  createdAt: new Date(),
  updatedAt: new Date()
});

print('MongoDB initialized successfully with sample data');
print('Demo login: coach@demo.com / password123');
print('Registration code: COACH2024');