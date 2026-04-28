const csvService = require('./csvDatabaseService');
const pgService = require('./postgresDatabaseService');

function getDataStore() {
  return (process.env.DATA_STORE || 'csv').toLowerCase();
}

function getService() {
  const store = getDataStore();
  if (store === 'postgres' || store === 'pg' || store === 'postgresql') {
    return pgService;
  }
  return csvService;
}

module.exports = new Proxy(
  {},
  {
    get(_target, prop) {
      const svc = getService();
      const value = svc[prop];
      if (typeof value === 'function') return value.bind(svc);
      return value;
    },
  }
);

