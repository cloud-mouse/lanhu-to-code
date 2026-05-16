# 框架代码模板

各前端框架的标准代码模板，生成代码时参考对应框架的模板。

---

## Vue 3 + Composition API

### 单文件组件模板 (SFC)

```vue
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import type { PropType } from 'vue'

// Props 定义
interface Props {
  title: string
  list?: Array<{ id: number; name: string }>
}

const props = withDefaults(defineProps<Props>(), {
  list: () => []
})

// Emits 定义
const emit = defineEmits<{
  (e: 'click', id: number): void
}>()

// 响应式状态
const loading = ref(false)
const data = ref([])

// 计算属性
const filteredList = computed(() => data.value.filter(item => item.active))

// 方法
const handleClick = (id: number) => {
  emit('click', id)
}

// 生命周期
onMounted(async () => {
  loading.value = true
  try {
    // TODO: 加载数据
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="page-name">
    <!-- 内容 -->
  </div>
</template>

<style scoped lang="scss">
.page-name {
  // 样式
}
</style>
```

### uni-app 页面模板

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { onShow, onLoad } from '@dcloudio/uni-app'

const list = ref([])

onLoad((options) => {
  // 页面加载
})

onShow(() => {
  // 页面显示
})
</script>

<template>
  <view class="page-name">
    <scroll-view scroll-y class="scroll-container">
      <!-- 内容 -->
    </scroll-view>
  </view>
</template>

<style scoped lang="scss">
.page-name {
  min-height: 100vh;
  background-color: #f5f5f5;
}
</style>
```

**uni-app 注意事项：**
- 使用 `view` 而非 `div`，`text` 而非 `span`
- 使用 `rpx` 单位（750rpx = 屏幕宽度）
- 图片使用 `<image>` 标签
- 导航使用 `uni.navigateTo()` 等 API
- 不支持 `<a>` 标签，用 `<navigator>` 替代

---

## React + TypeScript

### 函数组件模板

```tsx
import React, { useState, useEffect, useCallback, useMemo } from 'react'
import styles from './ComponentName.module.scss'

interface ComponentNameProps {
  title: string
  onAction?: (id: number) => void
}

const ComponentName: React.FC<ComponentNameProps> = ({ title, onAction }) => {
  const [loading, setLoading] = useState(false)
  const [data, setData] = useState<any[]>([])

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true)
      try {
        // TODO: 加载数据
      } finally {
        setLoading(false)
      }
    }
    fetchData()
  }, [])

  const handleClick = useCallback((id: number) => {
    onAction?.(id)
  }, [onAction])

  return (
    <div className={styles.container}>
      {/* 内容 */}
    </div>
  )
}

export default ComponentName
```

### React + Tailwind CSS 模板

```tsx
import React from 'react'

interface Props {
  title: string
}

const ComponentName: React.FC<Props> = ({ title }) => {
  return (
    <div className="min-h-screen bg-gray-50 p-4">
      {/* 使用 Tailwind 类名 */}
    </div>
  )
}

export default ComponentName
```

---

## 小程序（微信/支付宝）

### WXML 模板

```xml
<!-- pages/xxx/index.wxml -->
<view class="page-name">
  <view class="header">
    <text class="title">{{title}}</text>
  </view>
</view>
```

### WXSS 模板

```css
/* pages/xxx/index.wxss */
.page-name {
  min-height: 100vh;
  background-color: #f5f5f5;
}

.header {
  padding: 32rpx;
}

.title {
  font-size: 36rpx;
  font-weight: 600;
  color: #333;
}
```

### JS 模板

```javascript
// pages/xxx/index.js
Page({
  data: {
    title: '',
    list: []
  },

  onLoad(options) {
    this.setData({ title: options.title || '' })
  },

  handleTap(e) {
    const { id } = e.currentTarget.dataset
    // 处理点击
  }
})
```

---

## 通用样式模板

### SCSS（Vue/Angular）

```scss
// 使用 BEM 命名
.page-name {
  min-height: 100vh;
  background-color: #f5f5f5;

  &__header {
    display: flex;
    align-items: center;
    padding: 16px;
  }

  &__title {
    font-size: 18px;
    font-weight: 600;
    color: var(--text-primary, #333);
  }

  &__card {
    background: #fff;
    border-radius: 8px;
    padding: 16px;
    margin: 0 16px 12px;

    &--highlight {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: #fff;
    }
  }
}
```

### CSS Modules（React）

```css
/* ComponentName.module.scss */
.container {
  min-height: 100vh;
  background-color: #f5f5f5;
}

.header {
  display: flex;
  align-items: center;
  padding: 16px;
}
```

---

## 文件放置约定

| 框架 | 页面目录 | 组件目录 | 样式方式 |
|------|---------|---------|---------|
| Vue 3 (Vite) | `src/views/<name>/index.vue` | `src/components/` | `<style scoped lang="scss">` |
| Vue 3 (Nuxt) | `src/pages/<name>.vue` 或 `pages/<name>.vue` | `src/components/` 或 `components/` | `<style scoped lang="scss">` |
| React (Vite) | `src/pages/<name>/index.tsx` | `src/components/` | CSS Modules 或 Tailwind |
| React (Next.js) | `src/app/<name>/page.tsx` | `src/components/` | CSS Modules 或 Tailwind |
| uni-app | `src/pages/<name>/index.vue` | `src/components/` | `<style scoped lang="scss">` |
| 小程序 | `pages/<name>/` | `components/` | `.wxss` 文件 |
| Angular | `src/app/<name>/` | `src/app/shared/components/` | `.scss` 文件 |

**优先读取项目现有结构来决定放置路径。** 如果项目中已有 `src/views/`，就用 `views`；已有 `src/pages/`，就用 `pages`。
