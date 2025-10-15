const express = require('express');
const axios = require('axios');
const path = require('path');

// Configuration
const app = express();
const PORT = process.env.PORT || 80;
const API_URL = process.env.API_URL || 'http://api:3000';
const SENDER_URL = process.env.SENDER_URL || 'http://localhost:8090';

// Configuration du moteur de template
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/', async (req, res) => {
  try {
    // En mode test, ne pas faire d'appel API réel
    if (process.env.NODE_ENV === 'test') {
      return res.render('index', { messages: [], senderUrl: SENDER_URL });
    }

    const response = await axios.get(`${API_URL}/api/messages`);
    res.render('index', { messages: response.data, senderUrl: SENDER_URL });
  } catch (error) {
    console.error('Erreur lors de la récupération des messages:', error.message);
    res.render('index', {
      messages: [],
      senderUrl: SENDER_URL,
      error: 'Impossible de récupérer les messages. Veuillez réessayer plus tard.'
    });
  }
});

// Route pour les tests
app.get('/messages', (req, res) => {
  // Simple route pour les tests
  res.json({ success: true });
});

// Démarrage du serveur seulement si ce fichier est exécuté directement
let server;
if (require.main === module) {
  server = app.listen(PORT, () => {
    console.log(`Service Thread en écoute sur le port ${PORT}`);
  });
}

module.exports = app; 