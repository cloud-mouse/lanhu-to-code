# CSS 值提取与数据驱动尺寸计算

> v2.2 — 与 SKILL.md 数据权威优先级 + §0 白名单对齐。

## 数据权威优先级

| 优先级 | 来源 | 用途 |
|--------|------|------|
| 1 | `lanhu_get_ai_analyze_design_result` 返回的 **HTML+CSS** | 所有 CSS 属性值的主源 |
| 2 | Design Tokens（analyze 附带） | 仅当 HTML **缺少**某属性时补充（渐变、阴影等） |
| 3 | layer_tree / sketch_annotations | 仅当 HTML 与 Tokens 均缺项时的 fallback（坐标公式） |
| 4 | 设计截图 + 图像分析 | 仅 `SKILL.md §0` 白名单场景；其他情形仅核对元素是否遗漏，**不改 Spec 数值** |

生成代码时：**先复制 Spec 中的 CSS，再按 `UNIT_STRATEGY` 做单位换算。**

---

## 子元素粒度颜色提取

**颜色提取必须按最小可见单元逐一提取，而非按区域整体。**

错误示范：
```
| .coupon-card | 主色 | #946B41 | ← 整个卡片只取了一个颜色
```

正确示范（从 Spec 中逐选择器摘录）：
```
| .coupon-card-bg | background | #FFF4E6 |
| .coupon-value | color | #D80D29 |
| .coupon-btn-bg | background | linear-gradient(135deg, #F54E25, #D80D29) |
```

---

## 单位换算规则

**基准（与 `SKILL.md §2.2` 一致）：逻辑 375px / 物理 750px。**

以 `detect-tech-stack.sh` 输出的 `UNIT_STRATEGY` 为准：

| UNIT_STRATEGY | HTML/CSS（逻辑 px） | layer_tree（物理 px / @2x） | sketch_annotations（逻辑 px） |
|---------------|--------------------|------------------------------|------------------------------|
| `rpx` | × 2 | 直接使用 | × 2 |
| `rem` | ÷ root font-size | ÷ 2 ÷ root | ÷ root |
| `px` | 1:1 | ÷ 2 | 1:1 |

完整示例见 `SKILL.md §2.2`，本文档不重复。

---

## 何时使用 fallback 手算

**默认不需要。** 仅当 HTML Spec 中缺少以下信息时，才用 layer/annotations 按本节公式计算：

- 区域重叠负 margin（hero 与内容区交叉）
- absolute 装饰元素偏移
- HTML 未表达的 padding/gap（且 Tokens 也无）

计算公式见下文「重叠布局 fallback」。

**禁止**：在 HTML Spec 已给出完整 flex + margin/padding 的区域，再用坐标重算一遍。

---

## 布局方向确认

对含方向性的元素，以 **HTML Spec 的 DOM 顺序与 CSS 定位** 为准；fallback 时才用坐标：

```
| .milestone-label | position | 节点上方 |
| .milestone-status | position | label 下方 |
```

不能凭直觉判断上下左右。

---

## 重叠布局 fallback（仅 HTML 缺项时）

### a) 内容区与 hero 的重叠量

```
负 margin = 内容区起始Y(按 UNIT_STRATEGY 换算) - hero 高度
```

### b) 卡片内边距

```
padding = (卡片外框宽度 - 卡片内容宽度) / 2
```

### c) 相邻元素间距

```
间距 = next.top - prev.top - prev.height
```

### d) 元素尺寸

从 layer tree / slices 提取，不猜测。

---

## 流式区域（Spec 已给出 flex 时）

直接从 HTML Spec 复制：

- `display:flex` / `flex-direction` / `justify-content` / `align-items`
- `gap` / `padding` / `margin`
- 子元素宽高字号颜色

**不要**再用 annotations 重算 gap。

---

## 可见性校验（防止白字白底）

对每个文字元素：

1. 取 Spec 中的 `color`
2. 找最近祖先的 `background`（或兄弟 shape 的背景）
3. `color ≈ background` → `⚠ 可见性问题`，查是否需包裹 pill/badge
4. 参考 layer 兄弟节点是否有背景 shape

---

## 富文本检测（防止部分变色丢失）

当文案含 **数字、状态词、冒号关键信息**（如 `3人`、`已完成`、`人数：3`）：

1. 查 HTML Spec 是否已拆分为多个节点/span
2. 若 Spec 仅单色 → 对照设计截图拆分为多节点并分别设色
3. 禁止整段使用单一 textLayer 颜色

---

## 跨页面值复用验证

| 可复用 | 必须按当前 Spec 验证 |
|--------|---------------------|
| 组件结构、命名、框架用法 | border-radius、padding、gap、字号、icon 尺寸 |

验证：当前 Spec 有值 → 用 Spec；无值 → 查 Tokens；仍无 → 标注 TODO，**禁止**从其他页面抄数值。

---

## 切图内容分析

```
artboard 类切片 → 常含背景 → 直接设宽高，不加额外背景
shapeLayer 类切片 → 常透明底 → 外层 wrap + 背景色 + 内层 icon 尺寸
```

以当前 `lanhu_get_design_slices` 元数据为准，禁止照搬其他页面的 icon 写法。
