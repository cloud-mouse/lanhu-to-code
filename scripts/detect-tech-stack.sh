#!/bin/bash
# lanhu-to-code 技术栈自动检测
# 从项目文件中检测前端技术栈
# 输出格式化的技术栈信息供 skill 使用

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: 目录不存在: $PROJECT_ROOT"
  exit 1
fi

# ─── 辅助函数 ────────────────────────────────────────────────
# 检查 package.json 的 dependencies/devDependencies 中是否包含某个依赖
has_dep() {
  [ -f "$PROJECT_ROOT/package.json" ] || return 1
  PROJECT_ROOT="$PROJECT_ROOT" DEP_NAME="$1" node -e "
    const pkg = require(process.env.PROJECT_ROOT + '/package.json');
    const deps = Object.assign({}, pkg.dependencies, pkg.devDependencies);
    process.exit(deps[process.env.DEP_NAME] ? 0 : 1);
  " 2>/dev/null
}

# 检查某个文件是否存在
has_file() {
  [ -f "$PROJECT_ROOT/$1" ]
}

# ─── 检测框架 ────────────────────────────────────────────────
FRAMEWORK="unknown"

# uni-app（优先检测，因为它同时包含 Vue）
if has_dep "@dcloudio/uni-app" || has_dep "@dcloudio/vite-plugin-uni" || \
   has_file "src/manifest.json" || has_file "src/pages.json"; then
  FRAMEWORK="uni-app"

# Taro
elif has_dep "@tarojs/taro" || has_dep "@tarojs/cli"; then
  FRAMEWORK="taro"

# Next.js
elif has_dep "next"; then
  FRAMEWORK="next.js"

# Nuxt
elif has_dep "nuxt"; then
  FRAMEWORK="nuxt"

# Vue（从 package.json 版本号检测，不依赖 node_modules）
elif has_dep "vue"; then
  VUE_VER=$(PROJECT_ROOT="$PROJECT_ROOT" node -e "
    const pkg = require(process.env.PROJECT_ROOT + '/package.json');
    const deps = Object.assign({}, pkg.dependencies, pkg.devDependencies);
    const ver = deps['vue'] || '';
    const m = ver.match(/[~^]?(\\d+)/);
    console.log(m ? m[1] : '');
  " 2>/dev/null)
  if [ "$VUE_VER" = "3" ]; then
    FRAMEWORK="vue3"
  elif [ "$VUE_VER" = "2" ] || [ "$VUE_VER" = "1" ]; then
    FRAMEWORK="vue2"
  elif [ -f "$PROJECT_ROOT/node_modules/vue/package.json" ] && \
       grep -q '"3\.' "$PROJECT_ROOT/node_modules/vue/package.json" 2>/dev/null; then
    FRAMEWORK="vue3"
  else
    FRAMEWORK="vue"
  fi

# React
elif has_dep "react" && has_dep "react-dom"; then
  FRAMEWORK="react"

# Angular
elif has_dep "@angular/core"; then
  FRAMEWORK="angular"

# Svelte
elif has_dep "svelte"; then
  FRAMEWORK="svelte"

# 无 package.json 时，从文件结构推断
elif [ ! -f "$PROJECT_ROOT/package.json" ]; then
  if has_file "src/pages.json" || has_file "pages.json" || has_file "app.json"; then
    FRAMEWORK="mini-program"  # 小程序
  elif find "$PROJECT_ROOT/src" -maxdepth 3 -name "*.vue" -print -quit 2>/dev/null | grep -q .; then
    FRAMEWORK="vue"
  elif find "$PROJECT_ROOT/src" -maxdepth 3 -name "*.tsx" -print -quit 2>/dev/null | grep -q .; then
    FRAMEWORK="react"
  elif has_file "angular.json" || has_file "src/app/app.module.ts"; then
    FRAMEWORK="angular"
  fi
fi

# ─── 检测 UI 框架 ────────────────────────────────────────────
UI_FRAMEWORK="none"

if has_dep "element-plus"; then
  UI_FRAMEWORK="element-plus"
elif has_dep "element-ui"; then
  UI_FRAMEWORK="element-ui"
elif has_dep "ant-design-vue" || has_dep "ant-design-vue@next"; then
  UI_FRAMEWORK="ant-design-vue"
elif has_dep "antd"; then
  UI_FRAMEWORK="antd"
elif has_dep "vant" || has_dep "@vant/ui"; then
  UI_FRAMEWORK="vant"
elif has_dep "nutui" || has_dep "@nutui/nutui"; then
  UI_FRAMEWORK="nutui"
elif has_dep "uview-ui" || has_dep "uview-plus"; then
  UI_FRAMEWORK="uview"
elif has_dep "arco-design-vue" || has_dep "@arco-design/web-vue"; then
  UI_FRAMEWORK="arco-design"
elif has_dep "tdesign-vue-next" || has_dep "tdesign-vue"; then
  UI_FRAMEWORK="tdesign"
elif has_dep "@mui/material"; then
  UI_FRAMEWORK="mui"
elif has_dep "chakra-ui" || has_dep "@chakra-ui/react"; then
  UI_FRAMEWORK="chakra-ui"
elif has_dep "tailwindcss"; then
  UI_FRAMEWORK="tailwindcss"
fi

# ─── 检测 CSS 预处理器 ─────────────────────────────────────
CSS_PREPROCESSOR="css"

if has_dep "sass" || has_dep "node-sass" || has_dep "dart-sass"; then
  CSS_PREPROCESSOR="scss"
elif has_dep "less" || has_dep "less-loader"; then
  CSS_PREPROCESSOR="less"
elif has_dep "stylus" || has_dep "stylus-loader"; then
  CSS_PREPROCESSOR="stylus"
elif has_dep "tailwindcss"; then
  CSS_PREPROCESSOR="tailwind"
fi

# ─── 检测状态管理 ────────────────────────────────────────────
STATE_MANAGEMENT="none"

if has_dep "pinia"; then
  STATE_MANAGEMENT="pinia"
elif has_dep "vuex" || has_dep "vuex@next"; then
  STATE_MANAGEMENT="vuex"
elif has_dep "@reduxjs/toolkit" || has_dep "redux"; then
  STATE_MANAGEMENT="redux"
elif has_dep "zustand"; then
  STATE_MANAGEMENT="zustand"
elif has_dep "mobx"; then
  STATE_MANAGEMENT="mobx"
elif has_dep "jotai"; then
  STATE_MANAGEMENT="jotai"
elif has_dep "dva" || { has_dep "@tarojs/taro" && has_dep "redux"; }; then
  STATE_MANAGEMENT="dva"
fi

# ─── 检测构建工具 ────────────────────────────────────────────
BUILD_TOOL="unknown"

if has_dep "vite" || has_file "vite.config.ts" || has_file "vite.config.js"; then
  BUILD_TOOL="vite"
elif has_dep "webpack" || has_file "webpack.config.js" || has_file "webpack.config.ts"; then
  BUILD_TOOL="webpack"
elif has_file "vue.config.js"; then
  BUILD_TOOL="vue-cli"
elif has_file "next.config.js" || has_file "next.config.mjs"; then
  BUILD_TOOL="next"
elif has_file "nuxt.config.ts" || has_file "nuxt.config.js"; then
  BUILD_TOOL="nuxt"
elif has_file "angular.json"; then
  BUILD_TOOL="angular-cli"
fi

# ─── 检测包管理器 ────────────────────────────────────────────
PACKAGE_MANAGER="npm"

if [ -f "$PROJECT_ROOT/pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
elif [ -f "$PROJECT_ROOT/yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
elif [ -f "$PROJECT_ROOT/bun.lockb" ]; then
  PACKAGE_MANAGER="bun"
fi

# ─── 检测 TypeScript ────────────────────────────────────────
TYPESCRIPT="false"

if has_dep "typescript" || has_file "tsconfig.json" || \
   find "$PROJECT_ROOT/src" -maxdepth 3 -name "*.ts" -print -quit 2>/dev/null | grep -q .; then
  TYPESCRIPT="true"
fi

# ─── 检测路由 ────────────────────────────────────────────────
ROUTER="none"

if has_dep "vue-router"; then
  ROUTER="vue-router"
elif has_dep "react-router" || has_dep "react-router-dom"; then
  ROUTER="react-router"
elif has_dep "@angular/router"; then
  ROUTER="angular-router"
elif has_dep "next"; then
  ROUTER="next-router"
fi

# ─── 输出 ────────────────────────────────────────────────────
echo "=== 技术栈检测结果 ==="
echo "FRAMEWORK: $FRAMEWORK"
echo "UI_FRAMEWORK: $UI_FRAMEWORK"
echo "CSS_PREPROCESSOR: $CSS_PREPROCESSOR"
echo "STATE_MANAGEMENT: $STATE_MANAGEMENT"
echo "ROUTER: $ROUTER"
echo "BUILD_TOOL: $BUILD_TOOL"
echo "PACKAGE_MANAGER: $PACKAGE_MANAGER"
echo "TYPESCRIPT: $TYPESCRIPT"
echo ""

# ─── 检测设计 token 文件 ────────────────────────────────────
echo "=== 设计 Token 文件 ==="
TOKEN_FILES=""

for f in \
  "src/styles/variables.scss" "src/styles/variables.less" "src/styles/variables.css" \
  "src/styles/_variables.scss" "src/assets/styles/variables.scss" \
  "src/styles/theme.scss" "src/styles/theme.ts" "src/theme/variables.scss" \
  "tailwind.config.ts" "tailwind.config.js" \
  "src/styles/token.scss" "src/styles/design-token.scss" \
  "src/constants/theme.ts" "src/constants/colors.ts"; do
  if [ -f "$PROJECT_ROOT/$f" ]; then
    echo "TOKEN_FILE: $f"
    TOKEN_FILES="$TOKEN_FILES $f"
  fi
done

if [ -z "$TOKEN_FILES" ]; then
  echo "TOKEN_FILE: (未找到)"
fi

echo ""

# ─── 检测组件文档 ────────────────────────────────────────────
echo "=== 项目文档 ==="

DOC_FILES=""
for f in \
  "CLAUDE.md" "README.md" \
  "docs/components.md" "docs/组件文档.md" "docs/开发规范与组件文档.md" \
  "docs/dev-spec.md" "docs/tech-spec.md" "docs/design-spec.md"; do
  if [ -f "$PROJECT_ROOT/$f" ]; then
    echo "DOC: $f"
    DOC_FILES="$DOC_FILES $f"
  fi
done

if [ -z "$DOC_FILES" ]; then
  echo "DOC: (未找到项目文档)"
fi
