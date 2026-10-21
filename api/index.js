const { handleRequest } = require('../lib/handler');

module.exports = (req, res) => {
    return handleRequest(req, res);
};
