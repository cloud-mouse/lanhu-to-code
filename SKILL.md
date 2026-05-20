---
name: lanhu-to-code
version: 3.0.0
description: |
  Generates pixel-perfect frontend code from Lanhu URLs or design screenshots; auto-detects stack. Use when the user provides lanhuapp.com links, image paths (.png/.jpg/.jpeg/.webp/.svg), or asks with 还原设计稿/蓝湖转代码/按设计稿生成/pixel-perfect/切图/设计稿还原/UI还原/设计还原/图转代码/截图转代码/照着这个做/按这个图写页面/把这个设计稿写出来/帮我写这个页面. Do not use for annotation-only discussion without code generation, backend-only context, or when the user explicitly requests the design-to-code three-stage workflow. If docs/tech-spec.md exists or the user mentions 最高还原度/code review/三阶段, suggest design-to-code once without switching until they confirm.
---

# lanhu-to-code

> v3.0.0 — 回归简单主线：取数 → 内容校对 → 生成 → 验证

根据蓝湖链接或设计稿图片，自动识别项目技术栈，生成 1:1 像素级还原的前端代码。

**v3 相对 v2 行为变更（Breaking）：** Spec 与视觉明显矛盾时默认**列入待确认**，不得自动用截图覆盖 Spec 数值；须用户裁决后再改。

## 核心原则

1. **Spec 主源**：蓝湖 analyze 返回的 HTML+CSS 是 CSS 数值主源；Tokens/layer 只补缺项；截图只用于发现遗漏和白名单 fallback。
2. **内容先确认**：写代码前必须输出「元素勾选清单 + CSS 对照表」，让用户校对 AI 提取的设计内容（**缓存命中 fast-path** 见 §2.5）。
3. **像素级还原**：颜色、尺寸、间距、渐变、圆角、阴影不四舍五入、不简化、不凭感觉改。
4. **项目适配**：检测框架、样式方案、单位策略，迁移到目标框架，但保留设计数值。
5. **Token 精确映射**：仅当项目 token 与设计值完全一致时使用 token；近似 token 禁用；无匹配时保留精确值并标注 `⚠ 未映射`（不因此判为坏代码）。
6. **优先复用**：优先使用项目已有组件与工具函数；props / 公共 API 以源码或文档为准。
7. **完整输出**：不省略代码，不用 `// ...`、样式同上、大块省略。
8. **所见即所出**：设计稿中可见元素都要还原；设计稿没有的元素不得添加。
9. **本地资源**：切图下载到项目本地目录，最终代码禁用蓝湖 CDN URL。

## 数据权威

```
HTML+CSS Spec（主源）
  ↓ 仅缺项时补充
Design Tokens / layer / slices 元数据
  ↓ 仅白名单场景
设计截图 / 图像分析
```

**允许图像分析 fallback 的白名单：**

| 场景 | 触发信号 | 处理 |
|------|----------|------|
| 富文本同行多色 | 文案含数字、状态词、冒号关键信息 | 拆多节点，逐字读色 |
| 独立背景容器 | 白字白底、badge/pill 背景丢失 | 查兄弟 shape；仍缺则读图 |
| 渐变缺端点 | Spec 只有 `gradient:linear` | 查 Token；仍缺则读图 |
| 切图含背景判定 | 图标是否自带圆/方背景不确定 | 查 slices；仍不清楚则读图 |
| Spec 自相矛盾 | CSS 与视觉明显冲突 | 列入待确认，不自动覆盖 |
| Spec 缺坐标/间距 | 重叠量、padding、gap 缺失 | 用 `css-value-extraction.md` 公式 fallback |

不在白名单内时，截图只用于发现遗漏或明显错位，不得覆盖 Spec 已有数值。

## 主流程

```
[1] 准备数据：输入判断 + 技术栈 + MCP analyze(compact) + slices + 项目上下文
[2] 内容校对：区域视觉巡检（必要时）+ 元素勾选清单 + CSS 对照表 → 等用户确认 → 立即写缓存
[3] 生成代码：按 Spec 迁移到目标框架 + 下载/引用本地资源 + 追加缓存
[4] 验证交付：Fidelity Audit + 四项校验 + pitfalls + build
[5] 第二轮：只改问题区域，读缓存，不全量重写
```

用户要求最高还原度、项目存在 `docs/tech-spec.md`、或用户提到 code review / 三阶段时，可以提示是否切换 `design-to-code`；用户未明确切换时继续本 skill。

## 第 1 步：准备数据

### 1.1 输入与意图

| 输入 | 处理 |
|------|------|
| 蓝湖 URL | 走蓝湖 MCP analyze + slices |
| 图片/截图 | 读 `references/image-input-guide.md`，说明精度低于蓝湖 |
| 纯文本描述 | 追问蓝湖链接或截图 |

用户说「修改/改造/更新」或指定文件路径 → **改造模式**；否则 → **新建模式**。

### 1.2 技术栈与单位

运行：

```bash
bash scripts/detect-tech-stack.sh [项目根目录]
```

读取 `FRAMEWORK`、`UI_FRAMEWORK`、`CSS_PREPROCESSOR`、`PACKAGE_MANAGER`、`UNIT_STRATEGY`、`TOKEN_FILE`。若脚本失败，手动读 `package.json` / `pages.json` / `README.md`，并参考 `references/framework-patterns.md`。

**单位基准：**

| UNIT_STRATEGY | HTML/CSS 逻辑 px 换算 |
|---------------|------------------------|
| `rpx` | × 2（逻辑 375px / 物理 750px） |
| `rem` | ÷ root font-size；能精确就少位，否则最多 4 位小数，不补零 |
| `px` | 1:1 |

layer_tree / annotations 只在 Spec 缺值时使用；换算细则见 `references/css-value-extraction.md`。

### 1.3 蓝湖 MCP 适配

不同蓝湖 MCP 工具名可能不同。**调用前必须读取实际 schema，以 schema 为准**。

**URL 规范（降低错页）：** 尽量使用**项目级**蓝湖 URL（含 `tid`、`pid` 等），避免仅带单页 `docId` 的深链；若 MCP 要求从项目 URL 选 design，与用户核对后再 analyze。

**工具发现（排障）：** 首次调用前列出当前环境可用 MCP 工具，确认存在名称含 `lanhu` 或与蓝湖文档一致的服务；若无任何匹配工具再提示配置 MCP 或改用图片输入。

| 职责 | 典型工具（仅参考） | 关键参数 | 默认 include |
|------|-------------------|----------|--------------|
| 设计列表 | `lanhu_get_designs` / `lanhu_design(mode=list)` | `url` | 无 |
| 设计分析 | `lanhu_get_ai_analyze_design_result` / `lanhu_design(mode=analyze)` | `url`、design 标识、`compact` | `["html","tokens"]` |
| 切图 | `lanhu_get_design_slices` / `lanhu_design(mode=slices)` | `url`、design 标识、metadata | 单独调用 |

前置检查：

- 找不到蓝湖 MCP 工具 → 停止，提示用户配置 MCP 或改用图片输入。
- 仅项目 URL、未指定 design → 列出设计图让用户选，禁止自动选第一张。
- 用户说「全部页面」→ 每批最多 3 张 design；不要一次性拉全量。

`compact` 默认 **true**：analyze 返回 HTML 文件路径时，用 Read 工具按需读取，避免把整段 HTML 塞进上下文。极简单页（单 design、<20 元素、HTML <10KB）才可 `compact:false`。

**MCP 响应控量（强制）：**

- analyze 默认只取 `html + tokens`；不要在 analyze 里同时 include `layers + image + slices`。
- `slices` 必须走切图职责单独调用；不要放在 analyze 的 `include` 里。
- `layers` 只在 Spec 缺坐标/间距/层级关系时单独补取；不是默认数据。
- `image` 只在第 2 步视觉巡检触发时取；简单页或已有缓存时不取。
- 聚合型工具（如 `lanhu_design(mode="analyze")`）若支持 `include`，禁止使用 `["html","tokens","layers","image","slices"]` 这种全量组合。
- 出现 `Large MCP response` 警告后，立刻停止继续全量读取，改用：明确 design 名称 + `compact:true` + 最小 include + 按职责分开调用。

### 1.4 下载资源与项目上下文

1. 按 analyze 返回的 `local_path ← remote_url` 映射下载图片到项目约定目录。
2. 调用切图职责工具补全 icon / 背景 / 装饰图。
3. 排除无意义系统 UI 碎图（状态栏电池/WiFi 等）。
4. 读取项目组件、token、路由、编码规范；改造模式下读取目标文件。

## 第 2 步：内容校对（写代码前必做）

这一步是 v3 的核心：**让用户确认设计内容，而不是只确认流程信息**。

### 2.1 区域视觉巡检（条件触发）

触发条件：复杂页（>30 元素或多 design）、首次使用无缓存、用户要求「最高还原度/99%/严格还原」、改造模式差异大。

做法：

1. 查看 analyze 返回的设计截图或图片文件。**若本次 analyze 未附带截图/图片路径**（仅有 HTML+Spec 文件），按 `§1.3` 用 **image 职责单独补取**（只拉取 `image` 或 MCP 等价能力，可与 html/tokens 分次调用）；**禁止**为了一次拿到图而把 `html + tokens + layers + image + slices` 打成全量 `include`。
2. 按区域扫：页面背景、hero、卡片、列表、底部栏、浮层。
3. 只记录命中白名单或明显矛盾的项；一致项折叠。
4. Spec 与视觉冲突且不在白名单内 → 放入「待确认」，不自动改。

输出格式：

```markdown
## 区域视觉巡检
| 区域 | 视觉感知 | Spec 对应值 | 状态 |
|------|----------|-------------|------|
| Hero 标题 | 数字红色高亮 | textLayer 单色 #333 | 命中：富文本同行多色 |
| 卡片徽章 | 橙黄渐变 pill | 只有 gradient:linear | 命中：渐变缺端点 |
```

### 2.2 元素勾选清单（必输出）

按区域聚合输出，复杂页控制在 15–25 行；同类重复元素合并。

```markdown
## 元素勾选清单
| 区域 | 关键元素 | 分类 | 关键属性 / 切图 |
|------|----------|------|----------------|
| Hero | 返回箭头 | 切图-图标 | icon_back.png |
| Hero | 页面标题 | DOM 文字 | 80rpx / #FFFFFF / Bold |
| 内容区 | 优惠券卡片 ×3 | DOM 形状 + 文本 | bg #FFF4E6 / amount #D80D29 |
| 底部 | 主按钮 | DOM 形状 | 渐变 / 圆角 88rpx |
```

### 2.3 CSS 对照表（必输出）

只列关键/易错属性，复杂页控制在 10–20 行。必须包含：页面背景、主要渐变、圆角、字号、关键颜色、关键尺寸、白名单 fallback、未映射 token。

```markdown
## CSS 对照表
| 选择器/区域 | 属性 | 设计稿值 | Token 映射 | 来源 |
|-------------|------|----------|------------|------|
| 页面 | background | linear-gradient(...) | — | Spec |
| .hero-title | font-size | 80rpx | — | Spec |
| .coupon-amount | color | #D80D29 | ⚠ 未映射 | Spec |
| .badge | background | linear-gradient(...) | — | 图像 fallback：渐变缺端点 |
```

来源固定：`Spec` / `Token=<name>` / `图像 fallback:<场景>` / `公式 fallback:<场景>` / `⚠ Spec 矛盾`。

### 2.4 交互清单（必输出）

识别设计稿中可交互元素，给出基础前端行为；复杂业务/API 不猜，标 TODO。

```markdown
## 交互清单
| 元素/区域 | 交互类型 | 实现 | 备注 |
|-----------|----------|------|------|
| 返回箭头 | 点击 | 调用项目返回方法 / router.back / uni.navigateBack | 按项目框架 |
| Tab ×3 | 切换 | 本地 activeTab 状态 + class 切换 | 无接口 |
| 秒杀按钮 | 点击 | emit/click handler + TODO: 接口 | 不猜 API |
| 规则入口 | 点击弹窗 | 本地 showRuleModal | 若设计有弹窗则还原 |
```

规则：

- 只实现**设计稿可推断的基础 UI 交互**：点击、切换、弹窗、折叠、表单输入、勾选、路由返回/跳转占位、倒计时展示。
- 复用项目已有交互组件和方法；找不到接口/路由/业务规则时写 `TODO`，不要凭空发明。
- 多状态页面只实现设计稿给出的状态；缺失状态可预留 class/props，但不凭空设计 UI。
- 改造模式下保留已有 API、状态管理、路由逻辑，只替换/补充 UI 交互。

### 2.5 用户确认协议

**缓存命中 fast-path（可选）：** 在 **§1** 已确定目标 `design_name` 之后、开始 §2.1–2.4 之前，按 **§2.6** 的读取顺序检查是否已有 `.../<design-name>.md`。若**同时**满足：① 文件存在且可读；② 其中记录的蓝湖 `url` / `design_name` 与本次任务一致；③ `UNIT_STRATEGY` 与当前检测一致；④ 用户未要求重新拉 Spec / 未换稿 —— 则在本条消息中**仅输出**：任务摘要 + 缓存中「用户确认版」清单/对照表/交互的**摘要引用**（或原表前三行 + 「完整内容见缓存路径」）+ 询问「是否沿用缓存直接生成代码？」。用户确认沿用 → **跳过 §2.1–2.4 重扫**，直接进入 **§2.6**（可将沿用确认追加写入同路径缓存，不覆盖历史确认正文）再进入第 3 步。用户要求刷新或任一条件不满足 → 走完整§2.1–2.4。

把以下内容放在**同一条消息**中输出，然后等待用户确认（fast-path 已采纳时除外，见上）：

1. 任务摘要：输入类型、模式、技术栈、UNIT_STRATEGY、目标 design、切图目录。
2. 视觉巡检（如触发）。
3. 元素勾选清单。
4. CSS 对照表。
5. 交互清单。
6. 待确认项。

用户回复 OK/继续/确认 → **先写第 2 步确认缓存（见 §2.6），再进入第 3 步**。用户指出漏项、数值问题或交互问题 → 回到 Spec/截图/项目代码复核，更新清单后再次确认。

改造模式下还要附：

```markdown
## 改造变更清单
- 文件: <path>
- 保留: API / 状态 / 路由 / 业务逻辑
- UI 变更: <区域列表>
- 删除元素: <设计稿不存在的旧元素>
- 新增元素: <设计稿新增元素>
- 风险: <可能影响>
```

### 2.6 抗压缩缓存（确认后立即写）

第 2 步：在获得用户确认后（含 **§2.5** fast-path 的「沿用缓存」确认），**必须立刻写入或更新缓存**（fast-path 可仅追加一条沿用时间戳与用户原话，不覆盖历史确认正文），然后再生成代码。目的：即使后续上下文自动压缩，关键设计数据也不会丢。

**单一路径规则：** 候选目录按下列顺序检测**可写性**（目录存在且可创建文件，不存在则 `mkdir -p` 后重试）；**只对第一个成功的路径写入** `<design-name>.md`，禁止同时在多处各写一份副本以免漂移。

候选目录（写优先级）：

1. `.claude/lanhu-cache/`
2. `.cursor/lanhu-cache/`
3. `lanhu-cache/`（项目根下）

**读取规则：** 生成/修正前按**相同顺序**查找同名 `<design-name>.md`，使用**第一个存在**的文件；若多路径都存在且内容不一致，以**更高优先级路径**为准，并在本条回复中提示用户合并或删除旧文件。

缓存只存确认后的摘要，不存整段 HTML：

```markdown
# <design-name>
## Spec 来源
- url / design_name / analyze 时间 / UNIT_STRATEGY
- MCP 工具 / include / compact / Spec 文件路径（如有）

## 页面属性
- 画布 / 背景 / 安全区

## 元素勾选清单（用户确认版）
<第 2 步确认版>

## CSS 对照表（用户确认版）
<第 2 步确认版>

## 交互清单（用户确认版）
<第 2 步确认版>

## 切图映射
- <local_path> ← <remote_url> / <用途>

## fallback / 待确认
<图像 fallback、公式 fallback、Spec 矛盾、用户裁决>
```

**后续规则：**

- 第 3 步生成代码时，优先读本缓存，不依赖聊天上下文记忆。
- 生成过程中补充的新值（如更完整的切图映射）只追加到缓存，不覆盖用户确认内容。
- 自动压缩/恢复后，第一件事是读取该缓存，再继续生成或修正。

**缓存写失败：** 无法写入上述任一路径（权限、只读、目录不存在等）时，**停止进入第 3 步**，向用户说明原因并请其创建目录或调整权限；**不得以仅靠聊天记忆替代缓存**继续生成。

## 第 3 步：生成代码

### 3.1 迁移规则

1. 以 HTML+CSS Spec 为基准理解 DOM 与 class 意图。
2. 改写为目标框架组件（Vue SFC / React JSX / uni-app / 小程序等）。
3. CSS 值原样迁移，只做单位换算。
4. 使用项目已有组件时，props 必须以源码/文档为准；样式仍按 Spec 覆盖。
5. 切图使用本地路径，禁止 CDN。
6. 不省略代码，不用 `// ...` 占位。

允许：合并重复 wrapper、语义化标签、在视觉等价前提下把绝对定位块改为 flex/grid。  
禁止：修改颜色/圆角/字号/间距、渐变改纯色、删除可见节点、添加设计稿外元素。

### 3.2 生成顺序

1. 页面容器：背景、最小高度、安全区、滚动容器。
2. 从上到下生成区域。
3. 区域内部先 DOM 文字/形状，再图片/装饰。
4. 按第 2 步确认的交互清单实现基础交互、路由占位、数据 TODO。
5. 追加缓存（只补充生成期发现的资源映射/TODO，不覆盖第 2 步确认内容）。

### 3.3 缓存

缓存主写入点在 **§2.6**（用户确认后）；**§2.5** 的 fast-path 也可能触发沿用写入。第 3 步只做追加：生成文件路径、下载后的切图本地路径、TODO、编译命令等。

## 第 4 步：验证交付

### 4.1 Fidelity Audit（必做）

交付前对照 Spec 与代码，输出简表：

```markdown
## Fidelity Audit
| 检查项 | 状态 | 备注 |
|--------|------|------|
| 固定尺寸/高度未变形 | ✓/已修复 | - |
| overflow 裁剪等价 | ✓/已修复 | - |
| 颜色无漂移 | ✓/已修复 | - |
| 渐变未变纯色 | ✓/已修复 | - |
| 定位/offset 一致 | ✓/已修复 | - |
| font family/weight/size 保留 | ✓/已修复 | - |
| margin/padding 关键值一致 | ✓/已修复 | - |
| 图片本地路径，无 CDN | ✓/已修复 | - |
| 可见元素无遗漏/无新增 | ✓/已修复 | - |
```

有失败项不得声称完成。

### 4.2 四项强制校验

1. **可见性**：文字颜色与最近背景对比，白字白底必须查兄弟 shape 或图像 fallback。
2. **跨页复制**：只能复用结构/命名/组件用法；CSS 数值必须来自当前 Spec。
3. **富文本**：含数字/状态词/冒号关键信息的文案，检查是否需要拆分多节点。
4. **切图背景**：含背景切图不加额外 wrap 背景；透明图标才加 wrap。

### 4.3 pitfalls 与编译

- **控上下文**：先读 `references/pitfalls-signals.md` 扫识别信号；对命中项再 Read `references/pitfalls.md` 对应「失败 N」小节。**交付前**仍须完成下面 24 项核对（可逐条展开或全读 `pitfalls.md`）。
- 交付前核对 `references/pitfalls.md` 24 项；重点 1–16、21–24。
- uni-app：`npx uni build -p mp-weixin`
- Vue/React/Vite：`npm run build`
- 无 build 脚本：说明跳过原因。

### 4.4 可选渲染视觉核对

Web/H5 项目如果能启动本地预览，可用浏览器截图与设计图并排检查遗漏和明显错位。视觉核对不能覆盖已通过的 Spec 数值；发现差异先回 Spec 与项目样式覆盖原因。

## 第 5 步：第二轮修正

用户反馈后：

1. 只改问题区域，不全量重写。
2. **先读缓存**中的元素清单、CSS 对照表、切图映射和用户裁决；不要依赖聊天上下文记忆。
3. 缓存过期、设计稿变更或用户要求重新拉取时，才重新 analyze，仍默认 compact。
4. 只对修改区域重跑 Audit、四项校验和 build。

## 禁止事项

| 禁止 | 原因 |
|------|------|
| 跳过内容校对直接写代码（无确认且无 §2.5 fast-path 用户确认） | 容易漏元素/取错值 |
| 忽略 HTML+CSS Spec，仅从截图或 layer 重算 | 破坏数据权威 |
| 用截图覆盖 Spec 已有数值（白名单除外） | 易引入主观误差 |
| 近似 token 替代精确值 | 破坏还原度 |
| 省略代码或添加设计稿外元素 | 不可用/失真 |
| 猜测 API 路径或组件 props | 产生 bug |
| 使用蓝湖 CDN URL | 会过期 |
| 未指定 design 自动选第一张 | 易做错页 |

## 参考文件

| 文件 | 何时读取 |
|------|----------|
| `references/css-value-extraction.md` | Spec 缺属性、fallback 公式、四项校验 |
| `references/element-classification.md` | DOM vs 切图不确定、切图背景判断 |
| `references/pitfalls-signals.md` | 生成/交付前快速扫 24 条信号，控上下文 |
| `references/pitfalls.md` | 命中信号后展开细节、交付前逐项核对 |
| `references/framework-patterns.md` | 目标框架模板不熟 |
| `references/image-input-guide.md` | 图片输入 |
| `references/layout-patterns.md` | 复杂布局 |
| `scripts/detect-tech-stack.sh` | 技术栈与 UNIT_STRATEGY 检测 |
