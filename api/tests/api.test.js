/* eslint-env mocha */
const chai = require('chai');
const chaiHttp = require('chai-http');
const mongoose = require('mongoose');
const { MongoMemoryServer } = require('mongodb-memory-server');
const expect = chai.expect;

chai.use(chaiHttp);

let app;
let mongoServer;

before(async function() {
  this.timeout(10000); // Augmenter le timeout pour le démarrage de MongoDB Memory Server
  
  // Démarrer une instance MongoDB en mémoire pour les tests
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();
  
  // Fermer toute connexion existante
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
  
  // Se connecter à la BD en mémoire
  await mongoose.connect(mongoUri);
  console.log('Connecté à la base de données mémoire pour les tests');
  
  // Définir l'environnement de test
  process.env.NODE_ENV = 'test';
  process.env.DATABASE_URL = mongoUri;
  
  // Import après avoir configuré l'environnement
  const serverModule = require('../server');
  app = serverModule.app;
});

after(async () => {
  await mongoose.disconnect();
  await mongoServer.stop();
});

describe('API Forum', () => {
  beforeEach(async () => {
    // Vider la base de données avant chaque test
    const collections = mongoose.connection.collections;
    for (const key in collections) {
      const collection = collections[key];
      await collection.deleteMany({});
    }
  });

  describe('GET /api/messages', () => {
    it('devrait retourner tous les messages', async () => {
      const res = await chai.request(app).get('/api/messages');
      expect(res).to.have.status(200);
      expect(res.body).to.be.an('array');
    });

    it('devrait retourner un tableau vide quand il n\'y a pas de messages', async () => {
      const res = await chai.request(app).get('/api/messages');
      expect(res).to.have.status(200);
      expect(res.body).to.be.an('array').that.is.empty;
    });

    it('devrait retourner les messages dans l\'ordre décroissant de création', async () => {
      // Créer plusieurs messages
      await chai.request(app).post('/api/messages').send({ username: 'User1', content: 'Message 1' });
      await chai.request(app).post('/api/messages').send({ username: 'User2', content: 'Message 2' });
      await chai.request(app).post('/api/messages').send({ username: 'User3', content: 'Message 3' });

      const res = await chai.request(app).get('/api/messages');
      expect(res).to.have.status(200);
      expect(res.body).to.be.an('array').with.lengthOf(3);
      expect(res.body[0]).to.have.property('content', 'Message 3'); // Le dernier créé devrait être en premier
    });
  });

  describe('POST /api/messages', () => {
    it('devrait créer un nouveau message', async () => {
      const message = {
        username: 'TestUser',
        content: 'Ceci est un message de test'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(201);
      expect(res.body).to.be.an('object');
      expect(res.body).to.have.property('username', 'TestUser');
      expect(res.body).to.have.property('content', 'Ceci est un message de test');
    });

    it('devrait créer un message avec un timestamp', async () => {
      const message = {
        username: 'TestUser',
        content: 'Message avec timestamp'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(201);
      expect(res.body).to.have.property('createdAt');
      expect(res.body.createdAt).to.be.a('string');
    });

    it('devrait créer un message avec un _id MongoDB', async () => {
      const message = {
        username: 'TestUser',
        content: 'Message avec ID'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(201);
      expect(res.body).to.have.property('_id');
    });

    it('ne devrait pas créer un message sans username', async () => {
      const message = {
        content: 'Message sans username'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(400);
      expect(res.body).to.have.property('error');
    });

    it('ne devrait pas créer un message sans content', async () => {
      const message = {
        username: 'TestUser'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(400);
      expect(res.body).to.have.property('error');
    });

    it('ne devrait pas créer un message avec username vide', async () => {
      const message = {
        username: '',
        content: 'Contenu du message'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(400);
    });

    it('ne devrait pas créer un message avec content vide', async () => {
      const message = {
        username: 'TestUser',
        content: ''
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(400);
    });

    it('devrait supprimer les espaces en début et fin du username', async () => {
      const message = {
        username: '  TestUser  ',
        content: 'Message de test'
      };

      const res = await chai.request(app)
        .post('/api/messages')
        .send(message);

      expect(res).to.have.status(201);
      expect(res.body).to.have.property('username', 'TestUser');
    });
  });
});