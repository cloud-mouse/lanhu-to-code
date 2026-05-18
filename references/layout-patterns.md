# 常见移动端布局模式速查

遇到不确定如何实现的布局时，先匹配以下模式。匹配成功可直接使用对应实现方式，无需逐像素坐标推算。

---

## 单页整体布局

| 模式 | 特征 | 实现方式 |
|------|------|---------|
| 固定顶部 + 滚动内容 + 固定底部 | 导航栏固定、底部操作栏固定、中间可滚动 | nav: `position: fixed; top: 0`；content: `padding-top: navH; padding-bottom: barH; overflow-y: auto`；bar: `position: fixed; bottom: 0` |
| 全屏无滚动 | 所有内容一屏内展示 | `.page { height: 100vh; overflow: hidden }` + flex column 分配空间 |
| 渐变 Hero + 白色内容覆盖 | 顶部渐变背景，白色内容区上移覆盖 | hero: `position: absolute; top: 0; height: 60%`；内容区: `position: relative; z-index: 2` + 白色圆角背景 |

---

## 区域级布局

| 模式 | 特征 | CSS 关键属性 |
|------|------|-------------|
| 等宽网格 | N 列等宽等间距（如 3 列权益图标） | `display: flex; justify-content: space-between`；子项: 固定 width |
| 等宽网格（带间距） | N 列等宽，间距固定 | `display: flex; gap: Nrpx`；子项: `flex: 1` |
| 左文右按钮 | 左侧文字自适应，右侧操作按钮固定宽度 | `display: flex; justify-content: space-between; align-items: center` |
| 居中标题行 | 标题居中，两侧可能有装饰元素 | `display: flex; justify-content: center; align-items: center; gap: Nrpx` |
| 卡片列表 | 等宽卡片垂直排列 | `display: flex; flex-direction: column; gap: Nrpx` |
| 横向滚动标签 | 横向滚动的一排标签/卡片 | `scroll-view` + `white-space: nowrap; display: inline-flex` |
| 图标 + 上下双行文字 | 图标在上，标题和描述在下 | `display: flex; flex-direction: column; align-items: center`；文字区: `text-align: center` |

---

## 组件级布局

| 模式 | 特征 | CSS 关键属性 |
|------|------|-------------|
| 圆角渐变卡片 | 圆角 + 渐变背景 + 装饰图案 | `border-radius: Nrpx; background: linear-gradient(...); overflow: hidden`；装饰图: `position: absolute` |
| 底部购买栏 | 左侧价格 + 右侧渐变按钮 | `display: flex; justify-content: space-between; align-items: center`；按钮: `border-radius: Nrpx; background: linear-gradient(...)` |
| 勾选协议行 | 小图标 + 长文字 | `display: flex; align-items: center; gap: Nrpx`；图标: `flex-shrink: 0` |
| 轮播指示器 | 圆点指示当前页 | `position: absolute; bottom: Nrpx; left: 50%; transform: translateX(-50%)`；或 flex center |
| 删除线原价 | 价格 + 划线原价 | `display: flex; align-items: baseline; gap: Nrpx`；原价: `text-decoration: line-through` |
| 竖线分隔符 | 两个文字间竖线 | `width: 2rpx; height: Nrpx; background: color` |
| 自定义导航栏 | 状态栏适配 + 返回按钮 + 右侧操作 | `position: fixed; top: 0; padding-top: statusBarHeight`；内容: `height: 88rpx; display: flex; justify-content: space-between` |

---

## 布局策略判断速查

**快速判断当前区域属于流式还是重叠：**

```
问：这个区域内有没有元素互相覆盖或交叉？
├─ 没有 → 流式布局 → 用上表的 flex/grid 模式直接实现
└─ 有 → 重叠布局 → 需要 position: relative + absolute
    ├─ 哪个元素在上面？→ 给它 relative
    └─ 哪个元素在下面？→ 给它 absolute，通过 top/left 定位
```

**常见重叠场景：**
- 装饰图案叠在卡片上 → 卡片 relative，图案 absolute
- 内容区覆盖 hero 背景 → hero absolute，内容 relative + z-index
- 图标"坐"在进度条上 → 进度条 relative，图标 absolute
