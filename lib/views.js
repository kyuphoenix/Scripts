/**
 * 服务端 HTML 渲染模块
 */

function escapeHtml(str) {
    if (!str) return '';
    return str
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

/**
 * 渲染脚本列表首页
 */
function renderIndexPage({ scripts, host }) {
    const protocol = host.includes('localhost') || host.includes('127.0.0.1') ? 'http' : 'https';
    const baseUrl = `${protocol}://${host}`;
    const rootCommand = `curl -fsSL ${baseUrl} | sh`;

    const scriptItemsHtml = scripts.map(s => {
        const scriptCmd = `curl -fsSL ${baseUrl}/${s.id} | sh`;
        return `
        <div class="script-card">
            <div class="flex-1 min-w-0">
                <a href="/${s.id}" class="script-link">
                    ${escapeHtml(s.id)}
                </a>
                <p class="script-desc">${escapeHtml(s.desc)}</p>
            </div>
            <div class="flex items-center gap-2 shrink-0 w-full md:w-auto">
                <code class="code-box flex-1 md:w-80">${escapeHtml(scriptCmd)}</code>
                <button onclick="copyText(this, '${scriptCmd}')" class="btn shrink-0">
                    Copy
                </button>
            </div>
        </div>
        `;
    }).join('\n');

    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Scripts</title>
    <link rel="stylesheet" href="/style.css">
    <style>
        .flex { display: flex; }
        .flex-col { flex-direction: column; }
        .flex-1 { flex: 1 1 0%; }
        .items-center { align-items: center; }
        .justify-between { justify-content: space-between; }
        .gap-2 { gap: 0.5rem; }
        .gap-4 { gap: 1rem; }
        .space-y-3 > * + * { margin-top: 0.75rem; }
        .mb-1 { margin-bottom: 0.25rem; }
        .mb-6 { margin-bottom: 1.5rem; }
        .w-full { width: 100%; }
        .min-w-0 { min-width: 0; }
        .shrink-0 { flex-shrink: 0; }
        @media (min-width: 768px) {
            .md\\:flex-row { flex-direction: row; }
            .md\\:w-auto { width: auto; }
            .md\\:w-80 { width: 20rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1 class="page-title">Scripts</h1>

        <!-- 全功能一键安装向导命令 -->
        <div class="script-card script-card-primary mb-6">
            <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                    <span style="display:inline-block;width:8px;height:8px;border-radius:9999px;background:#34d399;"></span>
                    <span style="font-family:ui-monospace,monospace;font-size:1rem;font-weight:600;color:#fff;">quick-install</span>
                </div>
                <p class="script-desc">全自动交互式安装向导（协议自选、系统与硬件架构自动识别）</p>
            </div>
            <div class="flex items-center gap-2 shrink-0 w-full md:w-auto">
                <code class="code-box flex-1 md:w-80">${escapeHtml(rootCommand)}</code>
                <button onclick="copyText(this, '${rootCommand}')" class="btn shrink-0">
                    Copy
                </button>
            </div>
        </div>

        <!-- 专属免检测脚本列表 -->
        <div class="space-y-3">
            ${scriptItemsHtml}
        </div>
    </div>

    <script>
        function copyText(btn, text) {
            navigator.clipboard.writeText(text).then(() => {
                const orig = btn.innerText;
                btn.innerText = 'Copied';
                btn.classList.add('btn-copied');
                setTimeout(() => {
                    btn.innerText = orig;
                    btn.classList.remove('btn-copied');
                }, 1500);
            });
        }
    </script>
</body>
</html>`;
}

/**
 * 渲染单个脚本详情展示页面
 */
function renderScriptViewPage({ script, content, host }) {
    const protocol = host.includes('localhost') || host.includes('127.0.0.1') ? 'http' : 'https';
    const baseUrl = `${protocol}://${host}`;
    const scriptCmd = `curl -fsSL ${baseUrl}/${script.id} | sh`;

    return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHtml(script.id)} - Scripts</title>
    <link rel="stylesheet" href="/style.css">
    <style>
        .flex { display: flex; }
        .flex-col { flex-direction: column; }
        .items-center { align-items: center; }
        .justify-between { justify-content: space-between; }
        .gap-2 { gap: 0.5rem; }
        .gap-4 { gap: 1rem; }
        .mb-1 { margin-bottom: 0.25rem; }
        .mb-6 { margin-bottom: 1.5rem; }
        .shrink-0 { flex-shrink: 0; }
        @media (min-width: 640px) {
            .sm\\:flex-row { flex-direction: row; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="mb-6">
            <a href="/" style="color:#94a3b8;font-size:0.875rem;font-family:ui-monospace,monospace;text-decoration:none;">&larr; Back</a>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
                <h1 style="font-size:1.5rem;font-weight:700;font-family:ui-monospace,monospace;color:#fff;margin:0 0 0.25rem 0;">${escapeHtml(script.id)}</h1>
                <p class="script-desc">${escapeHtml(script.desc)}</p>
            </div>
            <div class="flex items-center gap-2 shrink-0">
                <code class="code-box" style="max-width:22rem;">${escapeHtml(scriptCmd)}</code>
                <button onclick="copyText(this, '${scriptCmd}')" class="btn shrink-0">
                    Copy
                </button>
            </div>
        </div>

        <div class="code-preview-wrap">
            <div class="code-preview-header">
                <span style="font-size:0.75rem;color:#94a3b8;font-family:ui-monospace,monospace;">${escapeHtml(script.id)}.sh</span>
                <button onclick="copyText(this, document.getElementById('scriptCode').innerText)" class="btn" style="padding:0.25rem 0.625rem;font-size:0.75rem;">
                    Copy Source
                </button>
            </div>
            <pre class="code-preview-content"><code id="scriptCode">${escapeHtml(content)}</code></pre>
        </div>
    </div>

    <script>
        function copyText(btn, text) {
            navigator.clipboard.writeText(text).then(() => {
                const orig = btn.innerText;
                btn.innerText = 'Copied';
                btn.classList.add('btn-copied');
                setTimeout(() => {
                    btn.innerText = orig;
                    btn.classList.remove('btn-copied');
                }, 1500);
            });
        }
    </script>
</body>
</html>`;
}

module.exports = {
    renderIndexPage,
    renderScriptViewPage
};
