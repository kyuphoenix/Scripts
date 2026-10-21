const http = require('http');
const { handleRequest } = require('./lib/handler');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    handleRequest(req, res);
});

server.listen(PORT, () => {
    console.log(`====================================================`);
    console.log(`🚀 sing-box 脚本分发与部署服务已启动`);
    console.log(`🌐 本地浏览器访问 : http://localhost:${PORT}`);
    console.log(`💻 终端测试命令   : curl -s http://localhost:${PORT} | head -n 20`);
    console.log(`====================================================`);
});
