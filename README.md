# Scripts

基于 Node.js 动态解耦拼接的 sing-box 节点配置脚本分发服务，支持一键部署到 Vercel。

## 路由规范

- **命令行访问 (`curl`/`wget`)**：
  - `curl -fsSL https://<domain>/ | sh`：全功能交互式引导安装（协议选择 + 系统与架构自检测）
  - `curl -fsSL https://<domain>/<id> | sh`：对应系统的专属免检测脚本（如 `/alpine-hy2`, `/debian-tuic`）
- **浏览器访问**：
  - `GET /`：显示 `Scripts` 脚本列表及一键复制（含全自动 `quick-install` 与各系统专属脚本）
  - `GET /<id>`：显示对应脚本的源码及复制
  - `GET /style.css`：暗黑极简全局样式表（内置定制滚动条规范）

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
