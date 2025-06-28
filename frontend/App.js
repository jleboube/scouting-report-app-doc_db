import React, { useState, useEffect } from 'react';
import { User, Plus, Edit3, Eye, Upload, Users, FileText, LogOut, Search } from 'lucide-react';

const ScoutingApp = () => {
  const [currentUser, setCurrentUser] = useState(null);
  const [currentView, setCurrentView] = useState('login');
  const [teams, setTeams] = useState([]);
  const [players, setPlayers] = useState([]);
  const [scoutingReports, setScoutingReports] = useState([]);
  const [selectedTeam, setSelectedTeam] = useState(null);
  const [selectedPlayer, setSelectedPlayer] = useState(null);
  const [editingReport, setEditingReport] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Authentication states
  const [loginForm, setLoginForm] = useState({ email: '', password: '' });
  const [registerForm, setRegisterForm] = useState({ email: '', password: '', registrationCode: '' });
  const [showRegister, setShowRegister] = useState(false);

  // API base URL - change this to your deployed backend URL
  const getApiBaseUrl = () => {
    // In production, this would be set via environment variables
    // For demo purposes, we'll use localhost
    try {
      return process?.env?.REACT_APP_API_URL || 'http://localhost:5000/api';
    } catch {
      return 'http://localhost:5000/api';
    }
  };
  const API_BASE_URL = getApiBaseUrl();

  // Token management - using in-memory storage for demo
  const [authToken, setAuthToken] = useState(null);
  const [userData, setUserData] = useState(null);

  const getToken = () => authToken;
  const setToken = (token) => setAuthToken(token);
  const removeToken = () => {
    setAuthToken(null);
    setUserData(null);
  };

  // Check for existing token on app load - disabled for demo
  useEffect(() => {
    // In a real deployment, this would check for stored authentication
    // For demo purposes, we start with no authentication
    console.log('Demo mode - no persistent authentication');
  }, []);

  // API helper function with demo mode fallback
  const apiCall = async (endpoint, options = {}) => {
    // For demo purposes, simulate API responses
    const simulateApiResponse = (endpoint, options) => {
      return new Promise((resolve, reject) => {
        setTimeout(() => {
          if (endpoint === '/auth/login') {
            const { email, password } = JSON.parse(options.body || '{}');
            if (email === 'coach@demo.com' && password === 'password123') {
              resolve({
                token: 'demo-token-' + Date.now(),
                user: { id: 'demo-user', email: 'coach@demo.com', role: 'coach' }
              });
            } else {
              reject(new Error('Invalid credentials'));
            }
          } else if (endpoint === '/auth/register') {
            const { email, password, registrationCode } = JSON.parse(options.body || '{}');
            if (registrationCode === 'COACH2024') {
              resolve({
                token: 'demo-token-' + Date.now(),
                user: { id: 'demo-user', email, role: 'coach' }
              });
            } else {
              reject(new Error('Invalid registration code'));
            }
          } else if (endpoint === '/teams') {
            resolve(sampleTeams);
          } else if (endpoint.startsWith('/players')) {
            const teamId = new URLSearchParams(endpoint.split('?')[1]).get('teamId');
            if (teamId) {
              resolve(samplePlayers.filter(p => p.teamId === teamId));
            } else {
              resolve(samplePlayers);
            }
          } else if (endpoint.startsWith('/reports')) {
            const playerId = new URLSearchParams(endpoint.split('?')[1]).get('playerId');
            if (playerId) {
              resolve(sampleReports.filter(r => r.playerId === playerId));
            } else {
              resolve(sampleReports);
            }
          } else {
            resolve({ message: 'Demo API response' });
          }
        }, 500); // Simulate network delay
      });
    };

    try {
      // In demo mode, use simulated responses
      return await simulateApiResponse(endpoint, options);
    } catch (error) {
      throw error;
    }
  };

  // Sample data for demo mode
  const sampleTeams = [
    { _id: '1', name: 'City Hawks', league: 'Metro League' },
    { _id: '2', name: 'Valley Eagles', league: 'Metro League' },
    { _id: '3', name: 'Mountain Lions', league: 'Regional League' }
  ];

  const samplePlayers = [
    { _id: '1', name: 'Mike Johnson', position: 'SS', jerseyNumber: '12', teamId: '1' },
    { _id: '2', name: 'Alex Rodriguez', position: 'CF', jerseyNumber: '7', teamId: '1' },
    { _id: '3', name: 'Sam Williams', position: '3B', jerseyNumber: '15', teamId: '2' },
    { _id: '4', name: 'Chris Davis', position: 'P', jerseyNumber: '21', teamId: '2' },
    { _id: '5', name: 'Jordan Brown', position: '1B', jerseyNumber: '8', teamId: '3' }
  ];

  const sampleReports = [
    {
      _id: '1',
      playerId: '1',
      scoutId: { email: 'coach@demo.com' },
      date: '2024-06-20',
      evaluations: {
        'hitting_contactAbility': 'Above Average',
        'hitting_power': 'Average',
        'fielding_hands': 'Excellent',
        'fielding_range': 'Above Average',
        'running_speed': 'Average'
      },
      notes: 'Strong defensive player with good contact skills. Shows potential for improvement in power hitting.',
      sprayChartUrl: null
    }
  ];

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

      setToken(response.token);
      setUserData(response.user);
      setCurrentUser(response.user);
      setCurrentView('dashboard');
      setLoginForm({ email: '', password: '' });
      loadTeams();
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

      setToken(response.token);
      setUserData(response.user);
      setCurrentUser(response.user);
      setCurrentView('dashboard');
      setRegisterForm({ email: '', password: '', registrationCode: '' });
      loadTeams();
    } catch (error) {
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = () => {
    removeToken();
    setCurrentUser(null);
    setCurrentView('login');
    setSelectedTeam(null);
    setSelectedPlayer(null);
    setEditingReport(null);
    setTeams([]);
    setPlayers([]);
    setScoutingReports([]);
  };

  // Data loading functions
  const loadTeams = async () => {
    try {
      const teamsData = await apiCall('/teams');
      setTeams(teamsData);
    } catch (error) {
      setError('Failed to load teams');
    }
  };

  const loadPlayers = async (teamId = null) => {
    try {
      const query = teamId ? `?teamId=${teamId}` : '';
      const playersData = await apiCall(`/players${query}`);
      setPlayers(playersData);
    } catch (error) {
      setError('Failed to load players');
    }
  };

  const loadReports = async (playerId = null) => {
    try {
      const query = playerId ? `?playerId=${playerId}` : '';
      const reportsData = await apiCall(`/reports${query}`);
      setScoutingReports(reportsData);
    } catch (error) {
      setError('Failed to load reports');
    }
  };

  // Scouting report evaluation categories
  const evaluationCategories = {
    hitting: {
      name: 'Hitting',
      skills: {
        contactAbility: { name: 'Contact Ability', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        power: { name: 'Power', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        plateApproach: { name: 'Plate Approach', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        hitForAverage: { name: 'Hit for Average', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] }
      }
    },
    fielding: {
      name: 'Fielding',
      skills: {
        hands: { name: 'Hands', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        range: { name: 'Range', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        armStrength: { name: 'Arm Strength', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        armAccuracy: { name: 'Arm Accuracy', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] }
      }
    },
    running: {
      name: 'Running',
      skills: {
        speed: { name: 'Speed', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        baserunning: { name: 'Baserunning IQ', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] }
      }
    },
    pitching: {
      name: 'Pitching',
      skills: {
        fastballVelocity: { name: 'Fastball Velocity', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        command: { name: 'Command', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        breaking: { name: 'Breaking Ball', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] },
        changeup: { name: 'Changeup', options: ['Poor', 'Below Average', 'Average', 'Above Average', 'Excellent'] }
      }
    }
  };

  // Report management functions
  const createNewReport = () => {
    if (!selectedPlayer) return;
    
    const newReport = {
      playerId: selectedPlayer._id,
      date: new Date().toISOString().split('T')[0],
      evaluations: {},
      notes: '',
      sprayChartUrl: null
    };
    
    setEditingReport(newReport);
    setCurrentView('editReport');
  };

  const saveReport = async (reportData) => {
    setLoading(true);
    try {
      if (editingReport._id) {
        // Update existing report (demo mode)
        const updatedReport = {
          ...editingReport,
          ...reportData,
          scoutId: { email: currentUser.email }
        };
        setScoutingReports(prev => prev.map(r => r._id === editingReport._id ? updatedReport : r));
      } else {
        // Create new report (demo mode)
        const newReport = {
          ...reportData,
          _id: 'report-' + Date.now(),
          scoutId: { email: currentUser.email }
        };
        setScoutingReports(prev => [newReport, ...prev]);
      }
      
      setEditingReport(null);
      setCurrentView('playerDetail');
    } catch (error) {
      setError('Failed to save report');
    } finally {
      setLoading(false);
    }
  };

  const editReport = (report) => {
    setEditingReport(report);
    setCurrentView('editReport');
  };

  const deleteReport = async (reportId) => {
    if (!window.confirm('Are you sure you want to delete this report?')) return;
    
    setLoading(true);
    try {
      // Demo mode - remove from local state
      setScoutingReports(prev => prev.filter(r => r._id !== reportId));
    } catch (error) {
      setError('Failed to delete report');
    } finally {
      setLoading(false);
    }
  };

  // Image upload handler (demo mode)
  const handleSprayChartUpload = (file) => {
    if (!file || !file.type.startsWith('image/')) {
      setError('Please select a valid image file');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      setEditingReport(prev => ({
        ...prev,
        sprayChartUrl: e.target.result
      }));
    };
    reader.readAsDataURL(file);
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
              <div className="bg-blue-50 border border-blue-200 rounded p-3 text-sm text-blue-800">
                <strong>Demo Credentials:</strong><br />
                Email: coach@demo.com<br />
                Password: password123
              </div>
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

  // Navigation Header
  const Header = () => (
    <>
      <div className="bg-yellow-100 border-b border-yellow-200 p-2 text-center">
        <p className="text-yellow-800 text-sm">
          <strong>Demo Mode:</strong> This is a demonstration. Use login: coach@demo.com / password123 or register with code: COACH2024
        </p>
      </div>
      <header className="bg-blue-800 text-white p-4 shadow-lg">
        <div className="flex justify-between items-center max-w-6xl mx-auto">
          <h1 className="text-2xl font-bold">Scout Pro</h1>
          <nav className="flex items-center space-x-4">
            <button 
              onClick={() => {
                setCurrentView('dashboard');
                loadTeams();
              }}
              className="flex items-center space-x-1 px-3 py-1 rounded hover:bg-blue-700 transition-colors"
            >
              <Users size={16} />
              <span>Teams</span>
            </button>
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
    </>
  );

  // Dashboard View
  if (currentView === 'dashboard') {
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <div className="max-w-6xl mx-auto p-6">
          {error && (
            <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-4">
              {error}
            </div>
          )}
          
          <h2 className="text-2xl font-bold mb-6">Teams</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {teams.map(team => {
              const teamPlayers = players.filter(p => p.teamId === team._id);
              return (
                <div key={team._id} className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
                  <h3 className="text-xl font-semibold mb-2">{team.name}</h3>
                  <p className="text-gray-600 mb-4">{team.league}</p>
                  <button 
                    onClick={async () => {
                      setSelectedTeam(team);
                      await loadPlayers(team._id);
                      setCurrentView('teamDetail');
                    }}
                    className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 transition-colors"
                  >
                    View Team
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Team Detail View
  if (currentView === 'teamDetail' && selectedTeam) {
    const teamPlayers = players.filter(p => p.teamId === selectedTeam._id);
    
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <div className="max-w-6xl mx-auto p-6">
          <div className="flex justify-between items-center mb-6">
            <div>
              <button 
                onClick={() => setCurrentView('dashboard')}
                className="text-blue-600 hover:text-blue-800 mb-2"
              >
                ← Back to Teams
              </button>
              <h2 className="text-2xl font-bold">{selectedTeam.name}</h2>
              <p className="text-gray-600">{selectedTeam.league}</p>
            </div>
          </div>

          <h3 className="text-xl font-semibold mb-4">Players</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {teamPlayers.map(player => {
              const playerReports = scoutingReports.filter(r => r.playerId === player._id);
              return (
                <div key={player._id} className="bg-white rounded-lg shadow-md p-4 hover:shadow-lg transition-shadow">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <h4 className="font-semibold">{player.name}</h4>
                      <p className="text-gray-600">#{player.jerseyNumber} - {player.position}</p>
                    </div>
                  </div>
                  <button 
                    onClick={async () => {
                      setSelectedPlayer(player);
                      await loadReports(player._id);
                      setCurrentView('playerDetail');
                    }}
                    className="bg-blue-600 text-white px-3 py-1 rounded text-sm hover:bg-blue-700 transition-colors"
                  >
                    View Player
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Player Detail View
  if (currentView === 'playerDetail' && selectedPlayer) {
    const playerReports = scoutingReports.filter(r => r.playerId === selectedPlayer._id);
    
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <div className="max-w-6xl mx-auto p-6">
          <div className="flex justify-between items-center mb-6">
            <div>
              <button 
                onClick={() => setCurrentView('teamDetail')}
                className="text-blue-600 hover:text-blue-800 mb-2"
              >
                ← Back to Team
              </button>
              <h2 className="text-2xl font-bold">{selectedPlayer.name}</h2>
              <p className="text-gray-600">#{selectedPlayer.jerseyNumber} - {selectedPlayer.position}</p>
            </div>
            <button 
              onClick={createNewReport}
              className="bg-green-600 text-white px-4 py-2 rounded flex items-center space-x-2 hover:bg-green-700 transition-colors"
            >
              <Plus size={16} />
              <span>New Report</span>
            </button>
          </div>

          <h3 className="text-xl font-semibold mb-4">Scouting Reports</h3>
          {playerReports.length === 0 ? (
            <div className="bg-white rounded-lg shadow-md p-8 text-center">
              <FileText size={48} className="mx-auto text-gray-400 mb-4" />
              <p className="text-gray-600 mb-4">No scouting reports yet</p>
              <button 
                onClick={createNewReport}
                className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 transition-colors"
              >
                Create First Report
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              {playerReports.map(report => (
                <div key={report._id} className="bg-white rounded-lg shadow-md p-4">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <p className="font-semibold">Report from {new Date(report.date).toLocaleDateString()}</p>
                      <p className="text-gray-600 text-sm">Scout: {report.scoutId?.email}</p>
                    </div>
                    <div className="flex space-x-2">
                      <button 
                        onClick={() => editReport(report)}
                        className="text-blue-600 hover:text-blue-800"
                      >
                        <Edit3 size={16} />
                      </button>
                      <button 
                        onClick={() => deleteReport(report._id)}
                        className="text-red-600 hover:text-red-800"
                      >
                        ×
                      </button>
                    </div>
                  </div>
                  {report.sprayChartUrl && (
                    <div className="mb-3">
                      <img 
                        src={report.sprayChartUrl}
                        alt="Spray Chart"
                        className="w-32 h-24 object-cover rounded border"
                      />
                    </div>
                  )}
                  {report.notes && (
                    <p className="text-gray-700 text-sm">{report.notes}</p>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    );
  }

  // Edit Report View
  if (currentView === 'editReport' && editingReport) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Header />
        <div className="max-w-4xl mx-auto p-6">
          <div className="mb-6">
            <button 
              onClick={() => setCurrentView('playerDetail')}
              className="text-blue-600 hover:text-blue-800 mb-2"
            >
              ← Back to Player
            </button>
            <h2 className="text-2xl font-bold">
              {editingReport._id ? 'Edit' : 'New'} Scouting Report
            </h2>
            <p className="text-gray-600">{selectedPlayer.name}</p>
          </div>

          <div className="bg-white rounded-lg shadow-md p-6">
            <div>
              {/* Date */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Date</label>
                <input
                  type="date"
                  value={editingReport.date}
                  onChange={(e) => setEditingReport(prev => ({ ...prev, date: e.target.value }))}
                  className="px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>

              {/* Evaluation Categories */}
              {Object.entries(evaluationCategories).map(([categoryKey, category]) => (
                <div key={categoryKey} className="mb-8">
                  <h3 className="text-lg font-semibold mb-4 text-gray-800 border-b pb-2">{category.name}</h3>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    {Object.entries(category.skills).map(([skillKey, skill]) => (
                      <div key={skillKey} className="space-y-2">
                        <label className="block text-sm font-medium text-gray-700">{skill.name}</label>
                        <select
                          value={editingReport.evaluations[`${categoryKey}_${skillKey}`] || ''}
                          onChange={(e) => setEditingReport(prev => ({
                            ...prev,
                            evaluations: {
                              ...prev.evaluations,
                              [`${categoryKey}_${skillKey}`]: e.target.value
                            }
                          }))}
                          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                        >
                          <option value="">Select rating...</option>
                          {skill.options.map(option => (
                            <option key={option} value={option}>{option}</option>
                          ))}
                        </select>
                      </div>
                    ))}
                  </div>
                </div>
              ))}

              {/* Spray Chart Upload */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Spray Chart</label>
                <div className="flex items-center space-x-4">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => e.target.files[0] && handleSprayChartUpload(e.target.files[0])}
                    className="hidden"
                    id="spray-chart-upload"
                  />
                  <label 
                    htmlFor="spray-chart-upload"
                    className="bg-gray-600 text-white px-4 py-2 rounded cursor-pointer hover:bg-gray-700 transition-colors flex items-center space-x-2"
                  >
                    <Upload size={16} />
                    <span>Upload Image</span>
                  </label>
                  {editingReport.sprayChartUrl && (
                    <img 
                      src={editingReport.sprayChartUrl}
                      alt="Spray Chart Preview"
                      className="w-24 h-16 object-cover rounded border"
                    />
                  )}
                </div>
                {!editingReport.sprayChartUrl && (
                  <p className="text-sm text-gray-500 mt-2">Select an image file to upload as spray chart</p>
                )}
              </div>

              {/* Notes */}
              <div className="mb-6">
                <label className="block text-sm font-medium text-gray-700 mb-2">Notes</label>
                <textarea
                  value={editingReport.notes}
                  onChange={(e) => setEditingReport(prev => ({ ...prev, notes: e.target.value }))}
                  rows="4"
                  className="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Additional observations and comments..."
                />
              </div>

              {/* Action Buttons */}
              <div className="flex justify-end space-x-4">
                <button 
                  onClick={() => setCurrentView('playerDetail')}
                  className="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  Cancel
                </button>
                <button 
                  onClick={() => saveReport(editingReport)}
                  disabled={loading}
                  className="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                  {loading ? 'Saving...' : 'Save Report'}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return null;
};

export default ScoutingApp;