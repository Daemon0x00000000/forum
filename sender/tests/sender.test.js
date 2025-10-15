/* eslint-env mocha */
const chai = require('chai');
const chaiHttp = require('chai-http');
const expect = chai.expect;

chai.use(chaiHttp);

// Import du serveur pour les tests
const app = require('../server');

describe('Sender Service', () => {
  describe('GET /', () => {
    it('devrait retourner le formulaire d\'envoi', (done) => {
      chai.request(app)
        .get('/')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.html;
          done();
        });
    });

    it('devrait contenir un formulaire avec les champs requis', (done) => {
      chai.request(app)
        .get('/')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res.text).to.include('username');
          expect(res.text).to.include('content');
          expect(res.text).to.include('form');
          done();
        });
    });

    it('devrait afficher le template EJS correctement', (done) => {
      chai.request(app)
        .get('/')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res.type).to.equal('text/html');
          expect(res.charset).to.equal('utf-8');
          done();
        });
    });
  });

  describe('POST /send', () => {
    it('devrait traiter l\'envoi du message', (done) => {
      const message = {
        username: 'TestUser',
        content: 'Ceci est un message de test'
      };

      // En mode test, on vérifie juste que le service répond correctement
      chai.request(app)
        .post('/send')
        .send(message)
        .end((err, res) => {
          expect(res).to.have.status(200);
          done();
        });
    });

    it('ne devrait pas accepter un message sans username', (done) => {
      const message = {
        content: 'Message sans username'
      };

      chai.request(app)
        .post('/send')
        .send(message)
        .end((err, res) => {
          expect(res).to.have.status(200);  // Renvoie la page avec une erreur
          expect(res).to.be.html;
          expect(res.text).to.include('requis');
          done();
        });
    });

    it('ne devrait pas accepter un message sans content', (done) => {
      const message = {
        username: 'TestUser'
      };

      chai.request(app)
        .post('/send')
        .send(message)
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.html;
          expect(res.text).to.include('requis');
          done();
        });
    });

    it('ne devrait pas accepter un message avec username et content vides', (done) => {
      const message = {
        username: '',
        content: ''
      };

      chai.request(app)
        .post('/send')
        .send(message)
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.html;
          expect(res.text).to.include('requis');
          done();
        });
    });

    it('devrait accepter un message avec username et content valides', (done) => {
      const message = {
        username: 'UserTest',
        content: 'Contenu du message valide'
      };

      chai.request(app)
        .post('/send')
        .send(message)
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.html;
          done();
        });
    });
  });

  describe('Gestion des erreurs', () => {
    it('devrait retourner 404 pour une route inexistante', (done) => {
      chai.request(app)
        .get('/route-inexistante')
        .end((err, res) => {
          expect(res).to.have.status(404);
          done();
        });
    });
  });
}); 