const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files from the build directory
app.use(express.static(path.join(__dirname, 'build')));

// Handle client-side routing - serve index.html for all routes
app.get('/*splat', (req, res) => {
  res.sendFile(path.join(__dirname, 'build', 'index.html'));
});

const server = app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});

// Graceful shutdown on CTRL+C
process.on('SIGINT', () => {
  console.log('\nShutting down gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
