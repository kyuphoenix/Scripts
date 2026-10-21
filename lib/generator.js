const fs = require('fs');
const path = require('path');

const SNIPPETS_DIR = path.join(__dirname, 'snippets');

// 读取 snippet 文件并统一为 LF 换行符
function readSnippet(filename) {
    const fullPath = path.join(SNIPPETS_DIR, filename);
    if (!fs.existsSync(fullPath)) {
        throw new Error(`Snippet not found: ${filename}`);
    }
    return fs.readFileSync(fullPath, 'utf8').replace(/\r\n/g, '\n');
}

// 脚本解耦构成配置表
const SCRIPT_DEFINITIONS = {
    'debian-hy2': {
        id: 'debian-hy2',
        title: 'Debian / Ubuntu - Hysteria 2',
        os: 'Debian / Ubuntu',
        proto: 'Hysteria 2',
        desc: '适用于 Debian / Ubuntu 等 systemd 体系的 Hysteria 2 自动化部署脚本 (glibc)',
        parts: [
            'header.sh',
            'prompt_hy2.sh',
            'deps_debian.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_hy2.sh',
            'service_systemd.sh',
            'result_hy2.sh'
        ]
    },
    'alpine-hy2': {
        id: 'alpine-hy2',
        title: 'Alpine Linux - Hysteria 2',
        os: 'Alpine Linux',
        proto: 'Hysteria 2',
        desc: '适用于 Alpine Linux 的 Hysteria 2 自动化部署脚本 (musl + OpenRC)',
        parts: [
            'header.sh',
            'prompt_hy2.sh',
            'deps_alpine.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_hy2.sh',
            'service_openrc.sh',
            'result_hy2.sh'
        ]
    },
    'debian-tuic': {
        id: 'debian-tuic',
        title: 'Debian / Ubuntu - TUIC v5',
        os: 'Debian / Ubuntu',
        proto: 'TUIC v5',
        desc: '适用于 Debian / Ubuntu 等 systemd 体系的 TUIC v5 自动化部署脚本 (glibc)',
        parts: [
            'header.sh',
            'prompt_tuic.sh',
            'deps_debian.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_tuic.sh',
            'service_systemd.sh',
            'result_tuic.sh'
        ]
    },
    'alpine-tuic': {
        id: 'alpine-tuic',
        title: 'Alpine Linux - TUIC v5',
        os: 'Alpine Linux',
        proto: 'TUIC v5',
        desc: '适用于 Alpine Linux 的 TUIC v5 自动化部署脚本 (musl + OpenRC)',
        parts: [
            'header.sh',
            'prompt_tuic.sh',
            'deps_alpine.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_tuic.sh',
            'service_openrc.sh',
            'result_tuic.sh'
        ]
    },
    'root': {
        id: 'root',
        title: '全自动交互部署脚本 (智能检测)',
        os: 'Debian / Ubuntu / Alpine 自适应',
        proto: 'Hysteria 2 / TUIC v5 自选',
        desc: '根路径专用交互式部署脚本，包含协议交互菜单、系统架构检测与动态分发',
        parts: [
            'header.sh',
            'root_orchestrator.sh',
            'acme.sh',
            'singbox_download.sh',
            'root_dispatch.sh'
        ]
    }
};

/**
 * 动态拼接完整脚本
 * @param {string} scriptId 
 * @returns {string} 拼接好的 shell 脚本
 */
function buildScript(scriptId) {
    const def = SCRIPT_DEFINITIONS[scriptId];
    if (!def) {
        return null;
    }

    const contents = def.parts.map(file => readSnippet(file).trim());
    return contents.join('\n\n') + '\n';
}

/**
 * 获取所有支持的脚本信息列表 (供网页展示)
 */
function getScriptList() {
    return [
        SCRIPT_DEFINITIONS['debian-hy2'],
        SCRIPT_DEFINITIONS['alpine-hy2'],
        SCRIPT_DEFINITIONS['debian-tuic'],
        SCRIPT_DEFINITIONS['alpine-tuic']
    ];
}

/**
 * 判断是否为命令行访问 (curl, wget, httpie 等)
 */
function isCliUserAgent(userAgent) {
    if (!userAgent) return false;
    return /curl|wget|httpie|fetch|aria2|urllib|python-requests/i.test(userAgent);
}

module.exports = {
    SCRIPT_DEFINITIONS,
    buildScript,
    getScriptList,
    isCliUserAgent
};
