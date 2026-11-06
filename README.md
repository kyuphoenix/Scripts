# Scripts

基于 Node.js 动态解耦拼接的 sing-box 节点配置脚本分发服务，支持一键部署到 Vercel。

## 协议支持

1. **Hysteria 2**：极速 UDP 双向加速代理
2. **TUIC v5**：基于 QUIC 协议的高性能拥塞控制代理
3. **AnyTLS**：抗 TLS-in-TLS 审查的高性能 TCP 代理
4. **VLESS + Reality**：偷自己真实证书 + 本地 Nginx 挂载静态网站回落伪装

## 路由规范

- **命令行访问 (`curl`/`wget`)**：
  - `curl -fsSL https://<domain>/ | sh`：**主引导向导与状态诊断面板**（系统状态自检、部署向导与运维管理双向导航入口）
  - `curl -fsSL https://<domain>/deploy | sh`（或 `/install`）：**代理协议交互式部署向导**（Hy2 / TUIC / AnyTLS / VLESS Reality，支持返回主菜单）
  - `curl -fsSL https://<domain>/manage | sh`：**节点服务日常维护管理面板**（监控状态、提取链接、启停重启、证书检测续期、实时日志，支持返回主菜单）
  - `curl -fsSL https://<domain>/uninstall | sh`：**一键完全卸载与环境清除**（停止并删除服务/配置/证书/静态网页，卸载 Nginx/acme.sh/辅助依赖包）
  - `curl -fsSL https://<domain>/<id> | sh`：对应系统的专属免检测脚本：
    - `/debian-hy2` / `/alpine-hy2`
    - `/debian-tuic` / `/alpine-tuic`
    - `/debian-anytls` / `/alpine-anytls`
    - `/debian-vless-reality` / `/alpine-vless-reality`
- **浏览器访问**：
  - `GET /`：显示 `Scripts` 脚本列表及一键复制
  - `GET /<id>`：显示对应脚本的源码及复制
  - `GET /style.css`：暗黑极简全局样式表

## 本地运行

```bash
npm start
# 访问 http://localhost:3000
```

## 部署到 Vercel

```bash
vercel --prod
```
或直接在 Vercel 控制台关联 GitHub 仓库即可。
