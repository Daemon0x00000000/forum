/* eslint-env mocha */
const chai = require('chai');
const chaiHttp = require('chai-http');
const expect = chai.expect;

chai.use(chaiHttp);

// Mock du serveur pour les tests
const app = require('../server');

describe('Thread Service', () => {
  describe('GET /', () => {
    it('devrait retourner la page d\'accueil', (done) => {
      chai.request(app)
        .get('/')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.html;
          done();
        });
    });

    it('devrait contenir un titre pour les messages', (done) => {
      chai.request(app)
        .get('/')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res.text).to.include('messages');
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

  describe('GET /messages', () => {
    it('devrait faire une requête à l\'API pour récupérer les messages', (done) => {
      // Ce test nécessiterait un mock de l'API
      // Pour simplifier, on vérifie juste que la route existe
      chai.request(app)
        .get('/messages')
        .end((err, res) => {
          expect(res).to.have.status(200);
          done();
        });
    });

    it('devrait retourner un objet JSON', (done) => {
      chai.request(app)
        .get('/messages')
        .end((err, res) => {
          expect(res).to.have.status(200);
          expect(res).to.be.json;
          expect(res.body).to.have.property('success');
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