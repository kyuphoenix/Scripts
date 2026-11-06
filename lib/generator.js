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
    'debian-anytls': {
        id: 'debian-anytls',
        title: 'Debian / Ubuntu - AnyTLS',
        os: 'Debian / Ubuntu',
        proto: 'AnyTLS',
        desc: '适用于 Debian / Ubuntu 的 AnyTLS 抗封锁代理部署脚本 (glibc + systemd)',
        parts: [
            'header.sh',
            'prompt_anytls.sh',
            'deps_debian.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_anytls.sh',
            'service_systemd.sh',
            'result_anytls.sh'
        ]
    },
    'alpine-anytls': {
        id: 'alpine-anytls',
        title: 'Alpine Linux - AnyTLS',
        os: 'Alpine Linux',
        proto: 'AnyTLS',
        desc: '适用于 Alpine Linux 的 AnyTLS 抗封锁代理部署脚本 (musl + OpenRC)',
        parts: [
            'header.sh',
            'prompt_anytls.sh',
            'deps_alpine.sh',
            'acme.sh',
            'singbox_download.sh',
            'config_anytls.sh',
            'service_openrc.sh',
            'result_anytls.sh'
        ]
    },
    'debian-vless-reality': {
        id: 'debian-vless-reality',
        title: 'Debian / Ubuntu - VLESS + Reality',
        os: 'Debian / Ubuntu',
        proto: 'VLESS + Reality',
        desc: '适用于 Debian / Ubuntu 的 VLESS+Reality 偷自己证书部署脚本 (Nginx 静态回落)',
        parts: [
            'header.sh',
            'prompt_vless_reality.sh',
            'deps_debian.sh',
            'acme.sh',
            'singbox_download.sh',
            'nginx_reality.sh',
            'config_vless_reality.sh',
            'service_systemd.sh',
            'result_vless_reality.sh'
        ]
    },
    'alpine-vless-reality': {
        id: 'alpine-vless-reality',
        title: 'Alpine Linux - VLESS + Reality',
        os: 'Alpine Linux',
        proto: 'VLESS + Reality',
        desc: '适用于 Alpine Linux 的 VLESS+Reality 偷自己证书部署脚本 (Nginx 静态回落)',
        parts: [
            'header.sh',
            'prompt_vless_reality.sh',
            'deps_alpine.sh',
            'acme.sh',
            'singbox_download.sh',
            'nginx_reality.sh',
            'config_vless_reality.sh',
            'service_openrc.sh',
            'result_vless_reality.sh'
        ]
    },
    'deploy': {
        id: 'deploy',
        title: '全自动交互部署脚本 (智能检测与多协议)',
        os: 'Debian / Ubuntu / Alpine 自适应',
        proto: '多协议自选 (Hy2 / TUIC / AnyTLS / Reality)',
        desc: '交互式代理协议部署向导，支持证书与历史配置复用，可随时返回主菜单',
        parts: [
            'header.sh',
            'uninstall.sh',
            'deploy_orchestrator.sh',
            'acme.sh',
            'singbox_download.sh',
            'root_dispatch.sh'
        ]
    },
    'manage': {
        id: 'manage',
        title: '节点服务管理与日常维护面板',
        os: 'Debian / Ubuntu / Alpine 通用',
        proto: '服务控制 + 日志监控 + 证书维护',
        desc: '交互式管理面板：监控服务状态、提取节点链接、启停服务、证书检测与实时日志',
        parts: [
            'header.sh',
            'detect_status.sh',
            'manage_orchestrator.sh',
            'uninstall.sh'
        ]
    },
    'uninstall': {
        id: 'uninstall',
        title: '一键完全卸载与环境清除脚本',
        os: 'Debian / Ubuntu / Alpine 通用',
        proto: 'Uninstall & Cleanup',
        desc: '停止并移除 sing-box 与 Nginx 服务，彻底删除配置文件、证书与静态网页，还原系统',
        parts: [
            'header.sh',
            'uninstall.sh',
            'uninstall_exec.sh'
        ]
    },
    'root': {
        id: 'root',
        title: '主引导向导 (系统状态检测与综合导航)',
        os: 'Debian / Ubuntu / Alpine 自适应',
        proto: '状态自检 + 部署配置 + 运维管理',
        desc: '主引导交互式入口：检测当前系统代理与证书部署状态，提供部署与日常维护双向入口',
        parts: [
            'header.sh',
            'detect_status.sh',
            'root_menu.sh'
        ]
    }
};

/**
 * 动态拼接完整脚本
 * @param {string} scriptId 
 * @param {object} options
 * @returns {string} 拼接好的 shell 脚本
 */
function buildScript(scriptId, options = {}) {
    const def = SCRIPT_DEFINITIONS[scriptId];
    if (!def) {
        return null;
    }

    const contents = def.parts.map(file => readSnippet(file).trim());
    let combined = contents.join('\n\n') + '\n';

    // 动态注入基准服务器地址
    const baseUrl = options.baseUrl || 'http://localhost:3000';
    combined = combined.replace(/__SERVER_URL__/g, baseUrl);

    return combined;
}

/**
 * 获取所有支持的脚本信息列表 (供网页展示)
 */
function getScriptList() {
    return [
        SCRIPT_DEFINITIONS['deploy'],
        SCRIPT_DEFINITIONS['manage'],
        SCRIPT_DEFINITIONS['uninstall'],
        SCRIPT_DEFINITIONS['debian-hy2'],
        SCRIPT_DEFINITIONS['alpine-hy2'],
        SCRIPT_DEFINITIONS['debian-tuic'],
        SCRIPT_DEFINITIONS['alpine-tuic'],
        SCRIPT_DEFINITIONS['debian-anytls'],
        SCRIPT_DEFINITIONS['alpine-anytls'],
        SCRIPT_DEFINITIONS['debian-vless-reality'],
        SCRIPT_DEFINITIONS['alpine-vless-reality']
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
