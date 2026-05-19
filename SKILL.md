---
name: lanhu-to-code
version: 2.2.0
description: |
  根据蓝湖链接或设计稿图片，生成 1:1 像素级还原的前端代码（目标还原度 ≥99%）。自动识别当前项目技术栈（Vue/React/Angular/Svelte/uni-app/小程序等）。

  TRIGGER — 满足以下任一条件即触发：
  1. 用户消息包含蓝湖 URL（lanhuapp.com）
  2. 用户提供了图片/截图文件路径（.png/.jpg/.jpeg/.webp/.svg）并要求生成页面或组件
  3. 用户说了以下关键词（含但不限于）：还原设计稿、蓝湖转代码、按设计稿生成页面、
     pixel-perfect、切图、设计稿还原、UI还原、设计还原、蓝湖链接、图转代码、截图转代码、
     照着这个做、按这个图写页面、把这个设计稿写出来、帮我写这个页面

  Do NOT trigger when:
  - 用户仅在讨论/查看设计标注，未要求生成代码
  - 用户在纯后端/非前端项目上下文中提供蓝湖链接
  - 用户显式要求使用 design-to-code 三阶段工作流

  主动提示走 design-to-code（不替换本 skill 触发，仅在第一次响应里附一句提示）：
  - 项目存在 `docs/tech-spec.md`
  - 用户提到「最高还原度」「code review」「三阶段」等字眼
---

# lanhu-to-code

> v2.2.0 — 目标还原度 ≥99%

根据蓝湖链接或设计稿图片，自动识别项目技术栈，生成像素级还原的前端代码。

## 核心原则

1. **设计 Spec 优先** — 蓝湖 MCP 返回的 **HTML+CSS 是数值主源**；Design Tokens / layer 数据仅作补充；设计截图主要用于发现遗漏，**Spec 已给出的 CSS 值不得被截图覆盖**
2. **Spec 局限场景允许图像分析** — 见 §0「Spec 局限性与允许的图像分析 fallback」白名单
3. **像素级还原** — 迁移到目标框架时，颜色、尺寸、间距、渐变、圆角等 CSS 属性值不得四舍五入、不得简化（如渐变改纯色）
4. **技术栈适配** — 检测项目框架与样式方案，改写 DOM 结构为框架组件，但保留 CSS 数值
5. **Token 映射（有则用之）** — 先查项目 design token；**完全匹配**设计稿值时用 `var(--xxx)`；无匹配或仅有近似 token 时用设计稿精确值并标注 `⚠ 未映射 token: <值>`
6. **优先复用** — 优先使用项目已有组件、工具函数；props 名称必须以文档/源码为准
7. **完整输出** — 不省略代码，不用 `// ...` 占位
8. **所见即所出** — 设计稿中每个可见元素都必须还原；不存在的元素绝对不能添加

### 数据权威优先级（蓝湖 URL 输入）

```
HTML+CSS（lanhu_get_ai_analyze_design_result）
    ↓ 补充（Spec 缺属性时）
Design Tokens / layer 元数据
    ↓ 仅在 §0 白名单场景使用
设计截图 + 图像分析
    ↓ 默认仅用于
核对元素是否遗漏（不得覆盖 Spec 已有数值）
```

---

## 第 0 步：Spec 局限性与允许的图像分析 fallback

蓝湖 `lanhu_get_ai_analyze_design_result` 返回的 HTML+CSS 不是全知的。以下场景已知 Spec 结构性不完整，**允许且只允许**用截图 + 图像分析作补充，并在缓存与产物中标注来源。

| 场景 | 信号 | 允许的 fallback | 强制标注 |
|------|------|----------------|---------|
| ① 富文本同行多色 | 单段文案含数字（`3人`/`¥199`/`80%`）、状态词（`已完成`/`进行中`）、冒号关键信息（`人数：X`） | 拆多节点逐字读色 | `⚠ 富文本分色：图像分析` |
| ② 文字独立背景容器 | Spec `color` 与最近祖先 `background` 同色/极相近（如白字白底） | 检查 layer 兄弟节点 shape，无则图像分析 shape 色值 | `⚠ pill/badge 背景：图像分析` |
| ③ 渐变缺色值 | Spec 出现 `gradient:linear` 但无 `linear-gradient(...)` 完整定义 | 查 Tokens；仍无则图像分析渐变方向与端点色 | `⚠ 渐变色：图像分析` |
| ④ 切图含/不含背景判定 | slices 数据 `type=artboard` 含背景；`shapeLayer` 不含背景 | 图像分析切图实际像素判断 | `⚠ 切图背景：实测` |
| ⑤ Spec 内自相矛盾 | 父 `width:100` 但子元素之和 `120` | 以视觉为准修正，并标注 | `⚠ Spec 矛盾，已按视觉解释` |
| ⑥ Spec 缺坐标导致 fallback 公式 | 重叠区域负 margin、卡片内边距等 Spec 未给 | 按 `references/css-value-extraction.md` fallback 公式手算 | `⚠ <项>：fallback 公式` |

**严格边界：**

- **不在白名单**的场景：截图只用于核对元素是否遗漏，不得回改 Spec 数值
- 白名单内每一项都必须在缓存文件「来源标注」段写明
- 白名单 ① ② ③ 自检见 §3.2 四项校验
- **主动触发机制见 §1.7.5**：复杂页 / 首次使用 / 用户要求最高还原度时，AI 必须主动扫一遍图，把命中的白名单场景一次性识别出来，不要等出错再回头

---

## 流程概览

```
[1] 数据准备 — 技术栈 + 蓝湖 MCP 三步 + 下载切图 + 项目上下文 + 区域视觉巡检（触发时） + 启动 ACK
[2] 代码生成 — 以 HTML+CSS 为 Spec 迁移到目标框架 + 写缓存
[3] 验证 — Fidelity Audit + 四项校验 + pitfalls + 编译（可选生成后视觉核对）
```

两轮策略：
- **第一轮**：按 Spec 生成完整代码
- **第二轮（定点修正）**：用户反馈后只改问题区域，对照 HTML Spec 与缓存

**高精度可选分支**：检测到 `docs/tech-spec.md`、或用户使用「最高还原度 / code review / 三阶段」字眼时，在第一次响应里**附一句**：「检测到适合三阶段工作流的信号，是否切换 `design-to-code`？」由用户决定；用户未明确要求 → 继续走本 skill。用户已说"用 design-to-code" → 本 skill 不接管。

---

## 第 1 步：数据准备

### 1.1 输入判断

| 输入类型 | 识别方式 | 处理方式 |
|---------|---------|---------|
| 蓝湖 URL | 包含 `lanhuapp.com` | 蓝湖 MCP 三步流程（见 §1.3） |
| 设计图图片 | 图片路径或截图 | 视觉分析，见 `references/image-input-guide.md` |
| 纯文本描述 | 仅文字 | 追问设计稿链接或截图 |

### 1.2 意图判断（新建 vs 改造）

用户说「修改/改造」或指定文件路径 → **改造模式**（先列变更范围，用户确认后再改）。否则 → **新建模式**。

### 1.3 技术栈与单位策略

```bash
bash scripts/detect-tech-stack.sh [项目根目录]
```

读取输出中的 `UNIT_STRATEGY`（`rpx` | `rem` | `px`），后续单位换算一律按此执行。失败时手动读 `package.json` / `pages.json`，并读 `references/framework-patterns.md`。

### 1.4 蓝湖 MCP 前置检查与工具适配

不同蓝湖 MCP 实现（如 `lanhu-mcp` / 部分聚合实现）的工具名与参数结构**会不同**。SKILL 不假设单一实现，按"职责"调用。

**1.4.1 前置检查（必做，未通过不得进入 §1.5）：**

1. 列出当前可用 MCP 工具，查找包含 `lanhu` 关键字的服务与工具
2. 没有任何蓝湖工具 → 告知用户「未检测到蓝湖 MCP，可改用图片输入（参见 `references/image-input-guide.md`），或先配置 MCP 后重试」，停止
3. 找到蓝湖工具 → **以实际 schema 中的工具名、参数名、默认值为准**；下文表格中的工具名仅为典型参考

**1.4.2 职责 → 典型工具映射：**

| 职责 | 典型工具名（仅参考） | 关键参数（以实际 schema 为准） |
|------|--------------------|-------------------------------|
| ① 列出设计图 | `lanhu_get_designs` / `lanhu_design(mode=list)` | `url` |
| ② 分析单/多设计图 | `lanhu_get_ai_analyze_design_result` / `lanhu_design(mode=analyze)` | `url`、design 标识（单数 string / 复数 array / 序号 / `'all'`，依实现）、`compact` |
| ③ 获取切图 | `lanhu_get_design_slices` / `lanhu_design(mode=slices)` | `url`、design 标识（单数或数组依实现）、是否含 metadata |

调用前必须读对应工具的 schema 描述（参数名/默认值/必填项），不要假设。

**1.4.3 URL 规范**：使用**不含 docId** 的项目级 URL（含 `tid`、`pid`）。示例：
`https://lanhuapp.com/web/#/item/project/stage?tid=xxx&pid=xxx`

**1.4.4 design 标识解析规则（适用于 ② ③）：**

| 用户输入 | 传给工具的标识 |
|---------|----------------|
| 给出精确设计图名称 | 该名称 |
| 给出序号「第 6 张」 | 使用 ① 返回的 `index`，**非名称前缀** |
| 仅项目 URL、未指定图 | **禁止自动选第一张**；列出列表请用户选择 |
| 用户要求"全部页面" | **禁止直接传 `'all'`**；按下文「批处理规则」分批传具体名称数组 |

**1.4.5 `compact` 参数（默认 `true`，强制开启以省上下文）：**

| 场景 | `compact` | 说明 |
|------|-----------|------|
| 默认 / 任何不确定情况 | `true` | HTML 不内联在 response，保存到本地文件；用 Read 工具读取该文件 |
| 极简单页（用户**明确告知**元素 <20、单设计图，且预估 HTML <10KB） | `false` | 允许内联，省一次文件读 |

`compact: true` 工作方式（按典型实现，具体字段以 schema 为准）：

1. analyze 工具的 response 文本含本地文件路径字段（典型名：`local_html_path` / `html_file` / `file`）
2. 用 **Read 工具**（不要用 `cat`/`Shell`）读取该路径得到完整 HTML+CSS
3. 路径已落地为文件，AI 可按需重读，避免一次性吞入上下文
4. 不保证字段名完全一致：若 response 中未明示路径字段，先按 schema 描述找；找不到才退回 `compact: false`

**适用收益**：大设计稿（>30KB HTML）走 compact 可节省 50–80% 的上下文 token；缓存只摘录"关键 CSS"段，**不要把整段 HTML 写进缓存**。

**1.4.6 批处理规则（多 design / `'all'` 场景，强制）：**

- 一次 analyze 调用涉及的 design 数量**长度 ≤ 3**
- 多于 3 张时拆批：**每批 ≤3 张 design 完成一个完整循环**（analyze → 写代码 → §3.1 Audit → 缓存）后再开下一批
- 跨批之间复用：技术栈检测、Token 文件、项目上下文只读一次
- `'all'` 字面值仅在 N≤3 张时使用；否则改为显式名称数组并分批

**1.4.7 数据契约（与 MCP 工具描述一致）**：② 返回的 HTML+CSS 中，所有 CSS 属性值必须原样作为生成依据；附带的 `local_path ← remote_url` 映射表用于下载资源。

**1.4.8 错误处理：**

| 情况 | 处理 |
|------|------|
| MCP 未配置 / 工具列表里没有蓝湖工具 | 提示用户配置蓝湖 MCP，或改用图片输入；停止生成 |
| 鉴权失败 / Cookie 无效 | 提示用户检查蓝湖 MCP 的 `LANHU_COOKIE`，停止生成 |
| design 标识无匹配 | 重新调用列表工具列出名称供用户选择 |
| 返回 HTML 为空 | 重试一次；仍失败则告知用户并建议换链接或截图输入 |

### 1.5 并行任务组（第 1 批）

同一批内并行：

```
A. detect-tech-stack.sh → FRAMEWORK / UNIT_STRATEGY / TOKEN_FILE
B. 蓝湖 MCP ① → ② → ③（②③ 可按 design 并行，但 ① 必须先完成）
C. 项目上下文：src/components/、token 文件、路由、改造模式下的目标文件
```

**多 design 时**：B 内的 ②③ 按 §1.4 批处理规则切片，每批 ≤3 张 design；A、C 跨批复用，不重复执行。

### 1.6 下载切图与静态资源

1. 按 analyze 返回的 **映射表** 下载全部图片到项目约定目录（如 `src/assets/`、`src/static/images/<page>/`）
2. 对每张设计图调用蓝湖 MCP 的**切图职责**工具（§1.4 ③）补全图标等小资源
3. 排除无意义系统 UI 碎图（状态栏电池/WiFi 等）

路径写法遵循目标框架（`@/assets/...`、uni-app `static/` 等）。蓝湖 CDN 链接的使用见「禁止事项」。

### 1.7 图片输入流程

非蓝湖 URL → `references/image-input-guide.md`（精度低于 MCP，首次输出须向用户说明）。

### 1.7.5 区域级视觉巡检（生成前主动看图）

> 历史上由 commit `56beeff` 引入，`73f6ff5` 误删，v2.2 起以"§0 白名单的主动版"复活。

**目的**：在写代码前**主动扫一遍设计图截图**，把 Spec 的盲区（§0 白名单 6 类）一次性识别出来，避免生成完再被动 fallback、来回返工。

**触发条件**（任一即触发，否则跳过）：

| 条件 | 判定 |
|------|------|
| 复杂页 | analyze 返回的 HTML 节点数估算 >30，或多 design |
| 首次使用 | 项目根 / `.claude/` / `.cursor/` 下均无 `lanhu-cache/` 目录 |
| 用户明确要求 | 字眼含「最高还原度」「99%」「像素级」「严格还原」等 |
| 改造模式且新旧差异大 | §2.7 变更清单条目 ≥5 |

不触发时跳过本步，直接走 §1.8。

**工作流：**

1. **拿到截图**：
   - analyze 工具的 response 已包含 image blocks → 直接看
   - 截图也走了文件路径（部分实现）→ 用 **Read 工具读图**（Claude 视觉模型自带读图能力，不依赖额外 MCP）
   - 工具完全不返回截图 → 跳过本步并在 ACK 中说明
2. **分区域扫描**：按 analyze 返回的 design 顺序，每张图按区域（页面背景 / hero / 内容卡片群 / 底部操作栏 / 装饰浮层 等）描述视觉特征：
   - 背景色 / 渐变方向与端点 / 阴影 / 圆角 / 边框
   - 文本对齐方式（居中 / 左 / 右） / 富文本分色信号（数字、状态词、冒号关键信息）
   - 元素堆叠关系（重叠 / 流式）
   - 文字与父背景的色对比（白字白底等可见性问题）
   - 切图区域内是否含背景色（圆形/方形 bg vs 纯图形）
3. **逐项对照 Spec**，输出**区域视觉巡检清单**：

   ```
   ## 区域视觉巡检清单
   | # | 区域 | 视觉感知 | Spec 对应值 | 状态 |
   |---|------|---------|-------------|------|
   | 1 | 页面背景 | 暖橙渐变 | linear-gradient(180deg, #FF770F, #FFB843) | 一致 |
   | 2 | hero 标题 | "已邀请 3 人"，"3" 红色高亮 | textLayer 单色 #FFFFFF | 命中 §0 ① 富文本分色 |
   | 3 | 卡片徽章 | 橙黄渐变 pill | 仅 gradient:linear，无端点 | 命中 §0 ③ 渐变缺色值 |
   | 4 | 优惠券缺口 | 8rpx 圆形挖洞 | Spec 写 16rpx | ⚠ Spec 矛盾 |
   ```

4. **状态分类与后续动作**：

   | 状态 | 后续动作 |
   |------|---------|
   | 一致 | 正常按 Spec 生成 |
   | 命中 §0 ① ② ③ ④ ⑤ ⑥ | 按 §0 白名单流程处理，结果写入缓存 §2.6 |
   | ⚠ Spec 矛盾 | 不自动改！在 §1.8 ACK 「待用户确认」段列出，等用户裁决 |

**权威协调（关键）：**

- 默认仍 Spec 优先
- 视觉发现差异 → 先回 Spec 复核（数值是否复制错、单位是否换算错）
- 复核仍不一致 → 命中 §0 ⑤ 标 `⚠ Spec 矛盾，已按视觉解释` 或交用户裁决
- **本步不允许越过 §0 白名单去改 Spec 数值**

**上下文控制：**

- 简单页（≤30 元素 且 已有缓存 且 用户未要求最高还原度）自动跳过
- 每张设计图只扫一遍，不重复
- 清单里"一致"行允许折叠为"区域 1–N 一致（略）"，仅列出命中白名单或矛盾的行
- 视觉巡检产物追加进 §1.8 ACK，不单独发一条消息

数据准备完成后、写代码前，**必须**先输出一次结构化 ACK，让用户在关键岔路口介入：

```
## 任务启动 ACK
- 输入类型: <蓝湖 URL | 设计图图片 | 文字描述>
- 模式: <新建 | 改造目标文件: src/...>
- 技术栈: FRAMEWORK=<...> / UI=<...> / UNIT_STRATEGY=<rpx|rem|px>
- 目标 design: <design_name | ⚠ 未指定，已列出 N 张请用户选择>
- Token 文件: <路径列表 | 未找到>
- 切图清单: <N 张，预计放 src/.../>
- 视觉巡检: <已执行（见下表）| 已跳过：<原因> | 工具不支持：<原因>>
- 高精度提示: <仅当检测到三阶段信号时附一句；否则省略>
- 待用户确认: <列出，无则写「无」>

# 当视觉巡检 = 已执行时，追加：
## 区域视觉巡检清单（仅命中白名单/矛盾的行，一致的折叠）
| # | 区域 | 视觉感知 | Spec 对应值 | 状态 |
|---|------|---------|-------------|------|
| ... | ... | ... | ... | 一致 / 命中 §0 X / ⚠ Spec 矛盾 |
```

- 改造模式下"待用户确认"必须包含 §2.7 的变更清单
- 视觉巡检命中 `⚠ Spec 矛盾` 的行必须进入"待用户确认"
- 任意一项为"未指定/未找到"且关键 → 必须等待用户回应后再生成
- ACK 与正式代码必须分开两条消息（让用户有终止机会）

---

## 第 2 步：代码生成

### 2.1 主路径：HTML+CSS Spec → 框架代码

**不要**从零根据 layer/annotations 重算布局。流程：

1. **读 Spec**：以 `lanhu_get_ai_analyze_design_result` 返回的 HTML+CSS 为基准，按区域理解 DOM 与 class 意图（`flex-row` → 横向 flex，`justify-between` → 两端对齐等）
2. **结构迁移**：改写为目标框架组件（Vue SFC / React JSX / uni-app 页面等），遵循项目目录与命名
3. **数值迁移**：所有 CSS 值从 Spec **原样复制**后，仅做**单位换算**（见 `UNIT_STRATEGY`），禁止「美化」数值
4. **补充缺失**：仅当 HTML 中某属性明显缺失时，用 Design Tokens 或 `references/css-value-extraction.md` 中的 fallback 公式补充，并标注来源
5. **组件映射**：见下文「组件映射」；覆盖样式时仍保持 Spec 中的尺寸与颜色

**允许的调整（不算破坏还原）：**

- 绝对定位块 → 在视觉等价前提下改为 flex/grid（**数值仍来自 Spec**）
- 合并重复 wrapper、语义化标签
- 使用项目组件替代裸 `div`/`input`

**禁止的调整：**

- 修改 rgba/hex、圆角、字号、间距
- 渐变改纯色；图片改 CSS 形状或 emoji
- 删除 Spec 中的可见节点

### 2.2 单位换算

**基准约定（统一术语，全文档共用）：**
- 蓝湖移动端设计稿默认 **逻辑 375px / 物理 750px**（两个表述等价；× 2 关系）
- `lanhu_get_ai_analyze_design_result` 返回的 HTML+CSS 数值是 **逻辑 px**
- layer_tree 的数值是 **物理 px（@2x）**，等于 rpx 值
- sketch_annotations 的数值是 **逻辑 px**

以 `detect-tech-stack.sh` 输出的 `UNIT_STRATEGY` 为准：

| UNIT_STRATEGY | HTML/CSS 逻辑 px 换算公式 | 示例：Spec `width: 375px` |
|---------------|---------------------------|--------------------------|
| `rpx` | × 2 | `width: 750rpx` |
| `rem` | ÷ root font-size | root=37.5 → `width: 10rem`；root=16 → `width: 23.4375rem` |
| `px` | 1:1 | `width: 375px` |

**示例（一行 Spec → 三种产物）：**

```
HTML Spec: padding: 12px 16px; font-size: 14px; color: #333;
- rpx: padding: 24rpx 32rpx; font-size: 28rpx; color: #333;
- rem (root=37.5): padding: 0.32rem 0.4267rem; font-size: 0.3733rem; color: #333;
- px: padding: 12px 16px; font-size: 14px; color: #333;
```

**规则：**
- 颜色、阴影颜色等无量纲值不换算
- `rem` 精度：能精确表达就少位（如 `12 / 37.5 = 0.32`），无法精确表达时**最多保留 4 位小数**并就近舍入（如 `16 / 37.5 ≈ 0.4267`）；不补零、不写 `0.3200`
- layer_tree / sketch_annotations 的数值仅在 **HTML Spec 缺该属性** 时作 fallback，见 `references/css-value-extraction.md`

### 2.3 元素分类

边生成边判断，详见 `references/element-classification.md`：

| 分类 | 实现 |
|------|------|
| DOM 文字 / 形状 | 框架标签 + CSS（数值来自 Spec） |
| 切图-图标 / 装饰 / 背景 | 本地图片路径 + 必要时背景色兜底 |

### 2.4 渐变色

1. Spec 中有完整 `linear-gradient` → 原样迁移
2. Spec 仅 `gradient:linear` 无色值 → 查 Tokens；仍无则 `/* TODO: 渐变色需确认 */` + 最接近的 Token/截图
3. 切图已含渐变 → 用切图，CSS 不重复
4. 文字渐变 → `background-clip: text`（或平台等价写法）

### 2.5 生成顺序

1. 页面容器（背景、最小高度、安全区）
2. 按 Spec 从上到下各区域
3. 交互逻辑（script / composable）
4. 路由（新建页时）

### 2.6 设计数据缓存

**缓存路径选择优先级**（自上而下首个命中即用）：

1. 项目根存在 `.claude/` 目录（Claude Code 项目）→ `.claude/lanhu-cache/<design-name>.md`
2. 项目根存在 `.cursor/` 目录（Cursor 项目）→ `.cursor/lanhu-cache/<design-name>.md`
3. 其他 → 项目根 `lanhu-cache/<design-name>.md`

首次写入时若 `.gitignore` 未包含上述目录，提示用户是否添加（默认不入库）。

```markdown
# <设计稿名称>
## Spec 来源
- analyze 时间: <ISO 时间戳>
- design_name / URL / Spec hash（前 8 位）

## 页面属性
- 画布: <宽>×<高>, UNIT_STRATEGY, 背景 <色值>

## 关键 CSS（从 HTML Spec 摘录，供第二轮修正）
- <选择器/区域>: <属性: 值>

## Token 映射
- <设计值> → var(--xxx) 或 ⚠ 未映射

## 图像分析 fallback 来源标注（§0 白名单）
- 富文本分色: <区域> → <颜色>
- pill 背景: <区域> → <颜色>
- 渐变: <区域> → <linear-gradient(...)>
- 切图背景: <切图> → 含 / 不含

## 区域视觉巡检产物（§1.7.5；未执行则省略此段）
- 巡检时间: <ISO>
- 触发条件: <复杂页 | 首次使用 | 用户要求 | 改造差异大>
- 命中白名单: <列出区域 + 状态>
- ⚠ Spec 矛盾: <区域 → 用户裁决：信 Spec / 信视觉 / 待定>

## 待确认
- <TODO 项>
```

**缓存有效性规则（§3.6 第二轮修正使用）：**

| 情况 | 处理 |
|------|------|
| design_name 未变 且 缓存生成 ≤24h | 信缓存，不重新 analyze |
| 用户明确说"设计稿改了 / 重新拉" | 重新 analyze，覆盖缓存 |
| 缓存 >24h 但 design_name 未变 | 询问用户是否重新 analyze |
| design_name 变了 | 必须重新 analyze |

### 2.7 改造现有页面

1. 读目标文件，理解业务逻辑
2. 在 §1.8 ACK 中输出变更清单，**等用户确认**：

   ```
   ## 改造变更清单
   - 文件: <path>
   - 保留: <API 调用 / 状态管理 / 路由 / 业务逻辑 ...>
   - UI 变更:
     - <区域 1>: <旧 → 新>
     - <区域 2>: <旧 → 新>
   - 删除元素（设计稿中不存在）: <列出>
   - 新增元素（设计稿新增）: <列出>
   - 风险: <可能影响的功能 / 兼容性>
   ```

3. 只改 UI 相关部分，保留 API/状态/路由逻辑
4. 涉及组件 props 调整时附"组件 API 影响清单"

---

## 第 3 步：验证

### 3.1 Fidelity Audit（必做，不可跳过）

对照 **HTML Spec** 与生成代码逐项核对（平台属性等价即可），并**强制按以下 schema 输出**：

```
## Fidelity Audit
| # | 检查项 | 状态 | 备注 |
|---|--------|------|------|
| ① | 固定高度（Spec 中 height 不被内容撑开） | ✓/✗/已修复 | <差异点 或 "-"> |
| ② | overflow: hidden 裁剪等价 | ✓/✗/已修复 | - |
| ③ | 颜色 rgba/hex 无漂移 | ✓/✗/已修复 | - |
| ④ | 渐变未变纯色（含端点色与角度） | ✓/✗/已修复 | - |
| ⑤ | 绝对定位 left/top 或等价 offset 一致 | ✓/✗/已修复 | - |
| ⑥ | font-family / weight / size 保留 | ✓/✗/已修复 | - |
| ⑦ | margin / padding 各方向一致 | ✓/✗/已修复 | - |
| ⑧ | 图片均本地路径，无 CDN | ✓/✗/已修复 | - |
| ⑨ | Spec 中每个可见元素在代码中存在 | ✓/✗/已修复 | <遗漏列表 或 "-"> |
| ⑩ | 差异分类：平台适配 / 错误 | ✓/✗/已修复 | <列出错误项> |
```

**输出规则：**
- 全部 ✓ 才可声称完成；任何 ✗ 必须在同一轮修复后改为"已修复"并附说明
- 平台适配差异（如 `px → rpx`）不算 ✗
- 与 §0 白名单 fallback 相关的差异标"已修复"并引用缓存 fallback 标注

### 3.2 四项强制校验（必做）

执行步骤见 `references/css-value-extraction.md`：

1. **可见性** — 每个文字 `color` 与最近可见背景对比；白字白底 → 查兄弟 shape 或包裹背景容器
2. **跨页复制** — 从其他页面借用的数值须与**当前** Spec 一致
3. **富文本** — 含数字/状态词/冒号分隔的文案，拆分为多节点并分别设色（对照 Spec 或截图）
4. **切图背景** — 含背景切图不加多余容器；透明底图标加对应 wrap

### 3.3 pitfalls 自检

读取 `references/pitfalls.md`，生成前快速扫"识别信号"段；交付前**逐条核对全部 24 项**——失败 13/14/15/16 同样属于高频错误（页面背景丢失、区域主色覆盖子元素、布局方向反、hero 重叠量靠猜），不得豁免。

### 3.4 编译验证

- uni-app：`npx uni build -p mp-weixin`（不用 dev）
- Vue/React/Vite：`npm run build`（不用 dev server）
- 无 build 脚本：说明跳过原因

### 3.5 可选视觉核对

> 与 §1.7.5 的区别：§1.7.5 是**生成前**主动扫图防 Spec 盲区；§3.5 是**生成后**对照渲染结果防遗漏，二者互补不互斥。

**允许**在 Fidelity Audit 之后做一次性视觉核对：

- 使用 analyze 返回的**设计截图**与本地预览截图对比
- **仅用于**发现遗漏元素或布局明显错位
- **禁止**用视觉结果覆盖已通过的 Spec 数值；发现差异时回到 Spec 查因或回 §1.7.5 复核

### 3.6 定点修正（第二轮）

1. 优先读 §2.6 缓存的「关键 CSS」段；缓存不足或失效（按 §2.6 缓存有效性规则）才重新调用蓝湖 MCP 的**分析职责**工具（§1.4 ②），且仍按 §1.4.5 `compact: true` 默认，仅 analyze 问题区域相关 design
2. 只改问题区域 CSS/结构
3. **局部 Audit**：仅对修改过的区域跑 §3.1 Audit 表（其他区域跳过）；§3.2 四项校验也只覆盖受影响项
4. **不重读 pitfalls 全文**；仅当用户反馈中触发了新失败信号时，按 `references/pitfalls.md` 目录定位单条失败的「正确做法」段
5. 编译验证

---

## 组件映射

- 项目有完全匹配组件 → 使用，样式用 Spec 覆盖
- UI 框架有对应组件 → 使用，**props 以源码/文档为准**
- 无匹配 → 新建并标注 `⚠ 新增组件`

---

## 禁止事项

| 禁止 | 原因 |
|------|------|
| 忽略 HTML Spec，仅从 layer/annotations 重算整套布局 | 与 MCP 契约冲突，易算错 |
| 修改 Spec 中的 CSS 数值（含四舍五入、渐变简化） | 破坏还原度 |
| 用设计截图覆盖 Spec 数值（§0 白名单场景除外） | 截图优先级最低 |
| 用近似 design token 替代精确色值 | 破坏还原度 |
| 省略代码、添加 Spec 外元素 | 不可用 / 失真 |
| 猜测 API 路径或组件 props | 产生 bug |
| 最终代码使用蓝湖 CDN 链接 | 会过期 |
| 未指定 design 时自动选列表第一项 | 易做错页 |
| 跳过 Fidelity Audit、四项校验 或 任务启动 ACK | 无法保证质量 |
| 用额外视觉分析**改写** Spec 中已有的 CSS 数值（§0 白名单场景除外） | 只能发现遗漏，不能改 Spec |

---

## 工具调用预算

按阶段控制，避免无意义重复调用。**计数规则：同一阶段并行发起的 N 个工具调用算 1 批**（不论 N=2 还是 N=20）。

| 阶段 | 建议批次（单批 ≤3 design） | 内容 |
|------|--------------------------|------|
| 数据准备 | 1–2 批 | detect + designs + analyze(compact) + slices×N + 下载×M + 上下文 |
| 生成 | 1 批 / 批 | 写代码 + 缓存（只存关键 CSS 摘录，不存 HTML 全文） |
| 验证 | 1 批 / 批 | Audit 输出 + build（最后一批做完再 build） |

- **简单页**（单 design、<30 元素）：总计约 3 批
- **多 design 复杂项目**：按 §1.4 批处理规则，每批 ≤3 张 design 完整循环（analyze → 写代码 → Audit），跨批不堆积 HTML 上下文
- **不得**为省批次跳过下载或 Audit
- 同一 design 的 slices 与下载可与 analyze 并行（前提：analyze 已先完成）

**上下文卫生：**

- `lanhu_get_ai_analyze_design_result` 默认 `compact: true`，HTML+CSS 走文件而非内联
- 第二轮修正（§3.6）优先读缓存关键 CSS，不重读 pitfalls 全文，除非用户反馈触发了新失败信号
- ACK / Audit / 缓存模板里"无内容"行允许省略

### 参考文件按需读取

| 文件 | 何时读取 |
|------|---------|
| `css-value-extraction.md` | HTML 缺属性、重叠布局 fallback、四项校验细则 |
| `element-classification.md` | 不确定 DOM vs 切图 |
| `pitfalls.md` | 生成前扫信号 + 交付前逐条核对 |
| `framework-patterns.md` | 不熟悉当前技术栈 |
| `image-input-guide.md` | 图片输入 |
| `layout-patterns.md` | 非常见布局模式 |

---

## 参考文档

- `references/css-value-extraction.md` — Spec 补充、fallback 计算、四项校验
- `references/element-classification.md` — 元素分类与决策树
- `references/pitfalls.md` — 24 个常见失败模式
- `references/framework-patterns.md` — 各框架模板
- `references/image-input-guide.md` — 图片输入降级
- `references/layout-patterns.md` — 布局模式速查
- `scripts/detect-tech-stack.sh` — 技术栈与 UNIT_STRATEGY 检测
