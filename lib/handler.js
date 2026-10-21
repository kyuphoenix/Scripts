const fs = require('fs');
const path = require('path');
const { buildScript, getScriptList, isCliUserAgent, SCRIPT_DEFINITIONS } = require('./generator');
const { renderIndexPage, renderScriptViewPage } = require('./views');

/**
 * 核心请求分发处理器
 */
function handleRequest(req, res) {
    const host = req.headers['host'] || 'localhost:3000';
    const parsedUrl = new URL(req.url, `http://${host}`);
    let pathname = parsedUrl.pathname || '/';

    // 0. 静态资源: /style.css
    if (pathname === '/style.css') {
        const cssPath = path.join(__dirname, '../public/style.css');
        if (fs.existsSync(cssPath)) {
            res.writeHead(200, {
                'Content-Type': 'text/css; charset=utf-8',
                'Cache-Control': 'public, max-age=86400'
            });
            return res.end(fs.readFileSync(cssPath, 'utf8'));
        }
    }

    // 去除路径尾部斜杠 (除根路径外)
    if (pathname.length > 1 && pathname.endsWith('/')) {
        pathname = pathname.slice(0, -1);
    }

    const userAgent = req.headers['user-agent'] || '';
    const isCli = isCliUserAgent(userAgent);

    // 1. 根路径请求: /
    if (pathname === '/') {
        if (isCli) {
            // curl 或 wget 访问: 返回全功能交互式引导脚本
            const scriptContent = buildScript('root');
            res.writeHead(200, {
                'Content-Type': 'text/plain; charset=utf-8',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Content-Disposition': 'inline; filename="install.sh"'
            });
            return res.end(scriptContent);
        } else {
            // 浏览器访问: 返回现代脚本列表界面
            const html = renderIndexPage({
                scripts: getScriptList(),
                host
            });
            res.writeHead(200, {
                'Content-Type': 'text/html; charset=utf-8',
                'Cache-Control': 'public, max-age=60'
            });
            return res.end(html);
        }
    }

    // 2. 匹配具体脚本请求: 如 /debian-hy2, /alpine-tuic (支持 .sh 后缀)
    let scriptId = pathname.replace(/^\//, '');
    if (scriptId.endsWith('.sh')) {
        scriptId = scriptId.slice(0, -3);
    }

    if (SCRIPT_DEFINITIONS[scriptId]) {
        const scriptDef = SCRIPT_DEFINITIONS[scriptId];
        const scriptContent = buildScript(scriptId);

        if (isCli) {
            // 命令行访问: 直接返回纯脚本文本
            res.writeHead(200, {
                'Content-Type': 'text/plain; charset=utf-8',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Content-Disposition': `inline; filename="${scriptId}.sh"`
            });
            return res.end(scriptContent);
        } else {
            // 浏览器访问: 返回带有代码高亮预览与一键复制的详情网页
            const html = renderScriptViewPage({
                script: scriptDef,
                content: scriptContent,
                host
            });
            res.writeHead(200, {
                'Content-Type': 'text/html; charset=utf-8',
                'Cache-Control': 'public, max-age=60'
            });
            return res.end(html);
        }
    }

    // 3. 404 未找到
    if (isCli) {
        res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        res.end(`echo "❌ 错误: 未找到请求的脚本 [${scriptId}]，支持的脚本列表: debian-hy2, alpine-hy2, debian-tuic, alpine-tuic"\n`);
    } else {
        res.writeHead(404, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(`<!DOCTYPE html><html><body style="background:#0b0f19;color:#fff;font-family:sans-serif;text-align:center;padding:50px;">
            <h1>404 - 页面或脚本未找到</h1>
            <p><a href="/" style="color:#38bdf8;">返回首页脚本列表</a></p>
        </body></html>`);
    }
}

module.exports = {
    handleRequest
};
