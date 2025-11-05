const express = require('express');
const router = express.Router();
const argon2 = require('argon2');
const csvService = require('../services/csvDatabaseService');

// Initialize CSV file on server start
csvService.initializeCsvFile();

// POST /api/register
router.post('/register', async (req, res) => {
  try {
    const { fullName, password, department } = req.body;

    // Validation
    if (!fullName || !password || !department) {
      return res.status(400).json({ 
        success: false, 
        message: 'Full Name, Password, and Department are required' 
      });
    }

    // Password validation
    const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
    if (!passwordRegex.test(password)) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 8 characters with 1 uppercase, 1 lowercase, 1 number, and 1 symbol'
      });
    }

    // Validate department
    const departments = csvService.getDepartments();
    if (!departments.includes(department)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid department'
      });
    }

    // Hash password
    const passwordHash = await argon2.hash(password);

    // Create user
    const user = await csvService.writeUser({
      fullName,
      passwordHash,
      department
    });

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        userId: user.userId,
        fullName: user.fullName,
        department: user.department,
        role: user.role
      }
    });
  } catch (error) {
    if (error.message === 'User with this name already exists') {
      return res.status(409).json({
        success: false,
        message: error.message
      });
    }
    console.error('Registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// POST /api/login
router.post('/login', async (req, res) => {
  try {
    const { fullName, password } = req.body;

    // Validation
    if (!fullName || !password) {
      return res.status(400).json({
        success: false,
        message: 'Full Name and Password are required'
      });
    }

    // Find user
    const user = await csvService.findUserByCredentials(fullName);
    
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Verify password
    try {
      const isValidPassword = await argon2.verify(user.passwordHash, password);
      if (!isValidPassword) {
        return res.status(401).json({
          success: false,
          message: 'Invalid credentials'
        });
      }
    } catch (error) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    res.json({
      success: true,
      message: 'Login successful',
      user: {
        userId: user.userId,
        fullName: user.fullName,
        department: user.department,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/departments
router.get('/departments', (req, res) => {
  try {
    const departments = csvService.getDepartments();
    res.json({
      success: true,
      departments: departments
    });
  } catch (error) {
    console.error('Departments error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// GET /api/user/:userId
router.get('/user/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const user = await csvService.getUserById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      user: {
        userId: user.userId,
        fullName: user.fullName,
        department: user.department,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

module.exports = router;

