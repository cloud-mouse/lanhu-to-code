# lanhu-to-code

> Claude Code Skill — 根据蓝湖链接或设计稿图片，自动识别项目技术栈，生成 **1:1 像素级还原**的前端代码

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
[1] 输入判断 + 技术栈检测 + 意图判断（并行）
        │
        ▼
[2] 获取设计数据 + 下载切图 + 视觉校验
        │
        ▼
[3] 设计分析（页面属性 + 元素分类 + CSS 值 + 四项强制校验）
        │                                          ↕
[4] 项目上下文 + 组件映射（与步骤 3 并行）
        │
        ▼
[5] 生成代码 + 自检
```

### 核心机制

| 机制 | 说明 |
|------|------|
| **四项强制校验** | 可见性校验 → 跨页面复制验证 → 富文本检测 → 切图内容分析，任何一项失败都需修正后再继续 |
| **数据驱动** | 所有尺寸/间距/颜色从蓝湖设计数据反推，不靠猜测 |
| **先看图再对数据** | 拿到设计稿后先看完整截图建立视觉认知，再对照 Design Tokens 核实背景色/渐变等细节，避免遗漏 |
| **元素精准分类** | 区分 DOM 节点（代码实现）和切图资源（图片实现），避免该用图片的地方用代码、该用代码的地方用图片 |
| **所见即所出** | 设计稿中的元素必须全部还原，不存在的元素绝不添加 |
| **24 个失败模式** | 从真实项目中总结的常见错误及规避方法，自检时逐一核对 |
| **智能确认节奏** | 默认连续执行，仅在复杂场景（>30 元素、多冲突、改造模式）时暂停等待用户确认 |

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
│   └── pitfalls.md                       # 24 个常见失败模式
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

## 工作流程示例

```
你：帮我还原这个蓝湖设计稿 https://lanhuapp.com/web/#/item/project/...

Claude Code：
[1/5] 输入判断 + 技术栈检测 + 意图判断
      → 蓝湖 URL ✓  检测到 Vue3 + Element Plus + SCSS  → 新建页面

[2/5] 获取设计数据 + 视觉校验
      → 蓝湖页面分析完成，切图下载完成
      → 截图核对 tokens：发现 hero 渐变 tokens 遗漏，已从截图补充

[3/5] 设计分析（页面属性 → 元素分类 → CSS 值 → 四项校验）

      页面属性：背景色 #F5F5F5, 750rpx 基准

      元素勾选清单（23 个元素，DOM×15 + 切图×8）：
      - [ ] 背景装饰图 (750×400) → 切图-背景 | hero_bg.png
      - [ ] "邀好友得奖励" → DOM 文字 | 80rpx, #FFFFFF, Bold
      - [ ] 副标题背景条 → DOM 形状 | #FFEDD8, 圆角12rpx
      ...

      ⚠ CSS 冲突速查表（3 条冲突，需确认）：
      | 选择器 | 属性 | tokens 值 | 实际值 |
      | .card-badge | background | #FFFFFF | linear-gradient(...) |

      四项校验：可见性 ✓  跨页复制 ✓  富文本 ✓  切图尺寸 ✓

[4/5] 项目上下文 + 组件映射
      → 组件文档 ✓ 设计 token ✓ 编码规范 ✓
      → 复用 5 个组件，新增 2 个组件

[5/5] 生成代码 + 自检

      ✓ 生成文件：src/pages/invite/index.vue
      ✓ 复用组件：NavBar, CouponCard, StepProgress
      ⚠ 新增组件：RewardCard, InviteRuleDialog（需 review）
      ⚠ 未映射 token：#FFEDD8
      ⚠ TODO 项：API 接口路径需确认
```

## 常见问题

### 不用蓝湖，只用设计图截图可以吗？

可以，但精度会降低。蓝湖提供精确的设计数据（坐标、色值、间距、切图），图片只能通过视觉分析估算。建议优先使用蓝湖链接。

### 支持 Figma / Sketch 吗？

目前仅支持蓝湖链接和设计图图片。设计图方式适用于任何设计工具的输出。

### 生成的代码质量如何保证？

Skill 内置了 4 项强制校验和 13 项自检清单，确保：
- 所有 CSS 值与设计稿一致（四项校验逐一核对）
- 所有可见元素都已还原（元素勾选清单）
- 使用项目已有的组件和设计 token
- 代码完整不省略

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT
