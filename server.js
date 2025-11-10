const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();

// Clean up temporary query engine files on startup
const cleanupTempFiles = () => {
  try {
    const prismaDir = path.join(__dirname, 'lib', 'generated', 'prisma');
    const files = fs.readdirSync(prismaDir);
    files.forEach(file => {
      if (file.startsWith('query_engine-windows.dll.node.tmp')) {
        const filePath = path.join(prismaDir, file);
        fs.unlinkSync(filePath);
        console.log(`Cleaned up temporary file: ${file}`);
      }
    });
  } catch (error) {
    console.log('No temporary files to clean up');
  }
};

cleanupTempFiles();

app.use(cors());
app.use(express.json());

// Auto-generate API endpoints for all models
async function generateAPIs() {
  // Mock data for tblcity
  const mockCities = [
    { id: 1, cityname: 'Karachi' },
    { id: 2, cityname: 'Lahore' },
    { id: 3, cityname: 'Islamabad' },
    { id: 4, cityname: 'Rawalpindi' },
    { id: 5, cityname: 'Peshawar' },
  ];

  // API endpoint for tblcity/getAll
  app.get('/api/tblcity/getAll', (req, res) => {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 10;
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedCities = mockCities.slice(startIndex, endIndex);

      res.json({
        data: paginatedCities,
        total: mockCities.length,
        page: page,
        limit: limit
      });
    } catch (error) {
      console.error('Error fetching cities:', error);
      res.status(500).json({ error: error.message });
    }
  });
}

// Get stored procedures - removed Prisma dependency
app.get('/api/stored-procedures', async (req, res) => {
  try {
    // This endpoint is no longer functional without Prisma
    res.json([]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get stored procedure parameters - removed Prisma dependency
app.get('/api/stored-procedures/:name/params', async (req, res) => {
  try {
    // This endpoint is no longer functional without Prisma
    res.json([]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get GL accounts for dropdown - removed Prisma dependency
app.get('/api/accounts', async (req, res) => {
  try {
    console.log('GL accounts endpoint - Prisma removed, returning empty array');
    // This endpoint is no longer functional without Prisma
    res.json([]);
  } catch (error) {
    console.error('Error fetching GL accounts:', error);
    res.status(500).json({ error: error.message });
  }
});

// Execute stored procedure - removed Prisma dependency
app.post('/api/reports/:name', async (req, res) => {
  try {
    console.log('Reports endpoint - Prisma removed, returning empty array');
    // This endpoint is no longer functional without Prisma
    res.json([]);
  } catch (error) {
    console.error('Error executing stored procedure:', error);
    res.status(500).json({ error: error.message });
  }
});

// Execute raw SQL query - removed Prisma dependency
app.post('/api/raw-query', async (req, res) => {
  try {
    const { query } = req.body;

    if (!query) {
      return res.status(400).json({ error: 'Query is required' });
    }

    console.log('Raw query endpoint - Prisma removed, returning empty array');
    // This endpoint is no longer functional without Prisma
    res.json([]);
  } catch (error) {
    console.error('Error executing raw query:', error);
    res.status(500).json({ error: error.message });
  }
});

// Test endpoint for mobile
app.get('/api/test', (req, res) => {
  res.json({
    message: 'Server is running!',
    timestamp: new Date().toISOString(),
    ip: req.ip,
    userAgent: req.get('User-Agent')
  });
});

// Initialize APIs
generateAPIs().then(() => {
  app.listen(3000, '0.0.0.0', () => {
    console.log('Server running on port 3000');
  });
});