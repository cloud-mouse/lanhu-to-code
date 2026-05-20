# lanhu-to-code

> Claude Code Skill — 根据蓝湖链接或设计稿图片，自动识别项目技术栈，生成 **1:1 像素级还原**的前端代码

**v3.0：** 默认「内容校对 → 确认后缓存」；可命中已有缓存 fast-path；Spec 与视觉矛盾时须待用户确认，禁止自动用图覆盖。详见根目录 `SKILL.md`。

## 它能做什么？

给 Claude Code 一个蓝湖设计稿链接或设计图截图，它会：

1. **自动检测你的项目技术栈** — Vue 2/3、React、Angular、Svelte、uni-app、小程序、Next.js、Nuxt 等
2. **识别 UI 框架** — Element Plus、Ant Design、Vant、Tailwind、MUI 等
3. **从蓝湖获取精确设计数据** — 颜色、间距、字号、渐变、阴影、切图
4. **生成像素级还原的完整代码** — 不省略、不简化、不猜测

## 工作原理

```
用户输入（蓝湖 URL / 设计图）
        │
        ▼
[1] 准备数据：技术栈（含 UNIT_STRATEGY）+ 蓝湖 MCP analyze(compact) + slices + 项目上下文
        ▼
[2] 内容校对：区域视觉巡检（必要时）+ 元素勾选清单 + CSS 对照表 → 等用户确认 → 立即写缓存
        │
        ▼
[3] 生成代码：以 HTML+CSS Spec 迁移到目标框架（数值原样，结构适配）
        │
        ▼
[4] 验证交付：Fidelity Audit + 四项校验 + pitfalls + 编译
```

### 核心机制

| 机制 | 说明 |
|------|------|
| **HTML+CSS Spec 主源** | analyze 返回的 CSS 为数值主源，Tokens/layer 只补缺项 |
| **内容先确认并缓存** | 写代码前输出元素勾选清单 + CSS 对照表 + 交互清单；用户确认后立即写缓存，抗上下文压缩 |
| **图像分析白名单** | 富文本分色 / 独立背景容器 / 缺端点渐变 / 切图背景 / 坐标公式 fallback；**Spec 矛盾须待用户确认**，禁止自动用图覆盖 Spec |
| **compact + 分批 + 最小 include** | analyze 默认 compact，只取 html+tokens；layers/image/slices 按需分开调用，全部页面按 ≤3 张 design 分批 |
| **Fidelity Audit** | 交付前逐项对照 Spec，失败必须修复 |
| **四项强制校验** | 可见性 → 跨页复制 → 富文本 → 切图背景，交付前必做 |
| **UNIT_STRATEGY** | 自动检测 rpx / rem / px；移动 UI 库无适配方案时输出警告 |
| **元素精准分类** | DOM 与切图分工明确，本地资源、不用 CDN |
| **所见即所出** | 设计稿元素全还原，不添加 Spec 外内容 |
| **命中缓存 fast-path** | 同 URL / design / `UNIT_STRATEGY` 且用户未换稿时，可沿用 `lanhu-cache` 跳过重复清单（见 `SKILL.md` §2.5） |
| **第二轮定点修正** | 用户反馈后只改问题区域，优先读缓存，不全量重写 |

## 安装

### 方式一：npx（推荐）

```bash
npx lanhu-to-code
```

### 方式二：npm 全局安装

```bash
npm install -g lanhu-to-code
```

### 方式三：手动安装

```bash
# 克隆仓库
git clone https://github.com/cloud-mouse/lanhu-to-code.git

# 复制到 Claude Code skills 目录
cp -r lanhu-to-code ~/.claude/skills/lanhu-to-code
```

### Cursor IDE

将仓库复制或符号链接到 `~/.cursor/skills/lanhu-to-code`（个人全局）或 `<项目根>/.cursor/skills/lanhu-to-code`（仅本项目）。目录内需包含 `SKILL.md`、`references/`、`scripts/`（与仓库结构一致）。

### 方式四：从源码链接（适合开发者）

```bash
git clone https://github.com/cloud-mouse/lanhu-to-code.git
cd lanhu-to-code
node install.js   # 创建符号链接到 ~/.claude/skills/
```

### 更新

```bash
# npx / npm 全局安装（自动更新到最新版）
npx lanhu-to-code

# 源码安装
cd lanhu-to-code && git pull && node install.js
```

### 卸载

```bash
# 从源码目录
node install.js --uninstall

# 或手动删除
rm -rf ~/.claude/skills/lanhu-to-code
```

### 查看版本

```bash
node install.js --version
```

## 使用方式

安装后，在 Claude Code 中打开你的前端项目，然后：

### 蓝湖链接

```
帮我还原这个蓝湖设计稿：https://lanhuapp.com/web/#/item/project/stage?pid=xxx&id=yyy
```

### 设计图图片

```
按这个设计图生成页面代码：/path/to/design.png
```

### 改造现有页面

```
按这个蓝湖设计稿更新 src/pages/home/index.vue：https://lanhuapp.com/...
```

### 直接粘贴截图

在 Claude Code 中粘贴设计稿截图，然后说：

```
按这个设计图生成页面
```

## 支持的技术栈

### 前端框架

Vue 2、Vue 3、React、Angular、Svelte、uni-app、Taro、Next.js、Nuxt、微信/支付宝小程序

### UI 框架

Element Plus、Element UI、Ant Design (Vue/React)、Vant、NutUI、uView、Arco Design、TDesign、MUI、Chakra UI、Tailwind CSS

### CSS 预处理器

SCSS、Less、Stylus、Tailwind、原生 CSS

### 状态管理

Pinia、Vuex、Redux、Zustand、MobX、Jotai、Dva

## 项目结构

```
lanhu-to-code/
├── SKILL.md                              # Skill 主文件（工作流定义）
├── scripts/
│   └── detect-tech-stack.sh              # 技术栈自动检测脚本
├── references/
│   ├── element-classification.md         # 元素分类规则与决策树
│   ├── css-value-extraction.md           # CSS 值提取与数据驱动尺寸计算
│   ├── image-input-guide.md              # 图片输入降级策略
│   ├── framework-patterns.md             # 各框架代码模板
│   ├── layout-patterns.md                # 常见移动端布局模式速查
│   ├── pitfalls-signals.md               # pitfalls 24 条识别信号速查（控上下文）
│   └── pitfalls.md                       # 24 个常见失败模式（全文）
├── install.js                            # 安装脚本
├── package.json
├── LICENSE
└── README.md
```

## 前置条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- 蓝湖设计稿链接（推荐）或设计图截图
- 如果使用蓝湖链接，需配置蓝湖 MCP Server

### 蓝湖 MCP Server 安装

本 skill 依赖 [lanhu-mcp](https://github.com/dsphper/lanhu-mcp) 获取蓝湖设计稿数据。

**1. 安装 lanhu-mcp（二选一）**

```bash
# 方式 A：Docker（推荐）
git clone https://github.com/dsphper/lanhu-mcp.git && cd lanhu-mcp
bash setup-env.sh          # 交互式引导配置 Cookie
docker-compose up -d

# 方式 B：源码运行（需 Python 3.10+）
git clone https://github.com/dsphper/lanhu-mcp.git && cd lanhu-mcp
pip install -r requirements.txt && playwright install chromium
export LANHU_COOKIE="你的蓝湖Cookie"   # 从浏览器开发者工具获取
python lanhu_mcp_server.py
```

**2. 在 Claude Code 中配置 MCP**

```json
{
  "mcpServers": {
    "lanhu": {
      "type": "http",
      "url": "http://localhost:8000/mcp?role=Developer&name=YourName"
    }
  }
}
```

> 如果不配置蓝湖 MCP，仍然可以通过设计图图片方式使用本 skill，但精度会降低（视觉分析 vs 精确设计数据）。

**MCP 调用顺序：** 以实际 MCP schema 为准，按「列表 → 分析 → 切图」职责调用。典型实现是 `lanhu_get_designs` → `lanhu_get_ai_analyze_design_result(compact: true)` → `lanhu_get_design_slices`。

## 工作流程示例

```
你：帮我还原这个蓝湖设计稿 https://lanhuapp.com/web/#/item/project/...

Claude Code：
[1] 技术栈检测 → Vue3 + Element Plus + UNIT_STRATEGY: px
[2] 蓝湖 MCP 列表/分析/切图 → 获取 HTML+CSS Spec + 本地 assets
[3] 输出元素勾选清单 + CSS 对照表 → 等你确认
[4] 按 Spec 生成 Vue SFC，Token 完全匹配处映射 var(--primary)
[5] Fidelity Audit 通过 + 四项校验 + npm run build
      ✓ src/pages/invite/index.vue
      ⚠ 未映射 token: #FFEDD8
```

## 常见问题

### 不用蓝湖，只用设计图截图可以吗？

可以，但精度会降低。蓝湖提供精确的设计数据（坐标、色值、间距、切图），图片只能通过视觉分析估算。建议优先使用蓝湖链接。

### 支持 Figma / Sketch 吗？

目前仅支持蓝湖链接和设计图图片。设计图方式适用于任何设计工具的输出。

### 生成的代码质量如何保证？

Skill 内置了四重防线：

- **内容校对**：写代码前先确认元素勾选清单 + CSS 对照表
- **Fidelity Audit**：交付前逐项对照 HTML Spec
- **四项强制校验**（可见性 / 跨页复制 / 富文本 / 切图背景）
- **24 个常见失败模式**自检清单（`references/pitfalls-signals.md` + `references/pitfalls.md`）

加上：
- compact + 分批避免上下文膨胀
- Spec 局限场景的图像分析 fallback 受白名单约束，越界一律标注
- 使用项目已有的组件和设计 token，代码完整不省略

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT
