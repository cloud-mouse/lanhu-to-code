# CSS 值提取与数据驱动尺寸计算

## 子元素粒度颜色提取

**颜色提取必须按最小可见单元逐一提取，而非按区域整体。**

错误示范：
```
| .coupon-card | 主色 | #946B41 | ← 整个卡片只取了一个颜色
```

正确示范：
```
| .coupon-card-bg | background | #FFF4E6 | 卡片背景 |
| .coupon-value | color | #D80D29 | ← 金额是红色，不是金色 |
| .coupon-symbol | color | #D80D29 | ¥ 符号同色 |
| .coupon-name | color | #946B41 | 名称是金色 |
| .coupon-btn-bg | background | linear-gradient(135deg, #F54E25, #D80D29) | 按钮渐变 |
| .coupon-btn-text | color | #FFFFFF | 按钮文字白色 |
```

## 布局方向确认

**对于每个含方向性的元素，必须明确标注其相对于父/兄弟元素的位置关系：**

```
| .milestone-label | position | 节点上方 | ← 不是下方 |
| .milestone-status | position | label 下方 | ← 在节点区域内 |
```

**不能凭直觉判断上下左右，必须以设计稿坐标数据为准。**

## 单位换算规则

| 数据来源 | 单位 | 换算为 rpx（750 基准） |
|---------|------|----------------------|
| `sketch_annotations` | 逻辑像素 | × 2 |
| `layer_tree` | @2x 像素 | 直接使用 |
| `slices.size` | @2x 像素 | 直接使用 |
| `HTML/CSS` (蓝湖输出) | 逻辑像素（已除以 @2x） | × 2 |

## 必须计算的值

### a) 内容区与 hero 的重叠量

```
负margin = 内容区起始Y(×2转rpx) - hero高度
```
例：内容 y=230 → 460rpx，hero=750rpx → margin-top: -290rpx

### b) 每张卡片的内边距（逐一计算，不统一）

```
padding = (卡片外框宽度 - 卡片内容宽度) / 2
```
不同卡片内容宽度不同 → padding 不同

### c) 相邻元素间距（从绝对坐标反推）

```
间距 = 下一个元素 top - 上一个元素 top - 上一个元素 height
```
不能用 margin-top 链式累加，必须从坐标差值计算

### d) 元素尺寸（从 layer tree / sketch 提取，不猜）

- 进度条高度、图标大小、分割线粗细、圆角缺口大小
- 切图已含背景的（如步骤图标），不要再加额外背景层
