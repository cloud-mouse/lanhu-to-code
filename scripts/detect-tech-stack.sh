#!/bin/bash
# lanhu-to-code 技术栈自动检测
# 从项目文件中检测前端技术栈
# 输出格式化的技术栈信息供 skill 使用

PROJECT_ROOT="${1:-.}"

if [ ! -d "$PROJECT_ROOT" ]; then
  echo "ERROR: 目录不存在: $PROJECT_ROOT"
  exit 1
fi

# ─── 一次性读取 package.json，输出 key=value ─────────────────
# 性能优化：避免反复启动 node 进程
PKG_INFO=""
if [ -f "$PROJECT_ROOT/package.json" ]; then
  PKG_INFO=$(PROJECT_ROOT="$PROJECT_ROOT" node -e "
    try {
      const pkg = require(process.env.PROJECT_ROOT + '/package.json');
      const deps = Object.assign({}, pkg.dependencies, pkg.devDependencies);
      const has = (name) => deps[name] ? '1' : '0';
      const ver = (name) => {
        const v = deps[name] || '';
        const m = v.match(/[~^]?(\d+)/);
        return m ? m[1] : '';
      };
      const lines = [
        'HAS_UNI_APP=' + has('@dcloudio/uni-app'),
        'HAS_UNI_VITE=' + has('@dcloudio/vite-plugin-uni'),
        'HAS_TARO_TARO=' + has('@tarojs/taro'),
        'HAS_TARO_CLI=' + has('@tarojs/cli'),
        'HAS_NEXT=' + has('next'),
        'HAS_NUXT=' + has('nuxt'),
        'HAS_VUE=' + has('vue'),
        'VUE_MAJOR=' + ver('vue'),
        'HAS_REACT=' + has('react'),
        'HAS_REACT_DOM=' + has('react-dom'),
        'HAS_ANGULAR=' + has('@angular/core'),
        'HAS_ANGULAR_ROUTER=' + has('@angular/router'),
        'HAS_SVELTE=' + has('svelte'),
        'HAS_ELEMENT_PLUS=' + has('element-plus'),
        'HAS_ELEMENT_UI=' + has('element-ui'),
        'HAS_ANTV=' + (has('ant-design-vue') === '1' || has('ant-design-vue@next') === '1' ? '1' : '0'),
        'HAS_ANTD=' + has('antd'),
        'HAS_VANT=' + (has('vant') === '1' || has('@vant/ui') === '1' ? '1' : '0'),
        'HAS_NUTUI=' + (has('nutui') === '1' || has('@nutui/nutui') === '1' ? '1' : '0'),
        'HAS_UVIEW=' + (has('uview-ui') === '1' || has('uview-plus') === '1' ? '1' : '0'),
        'HAS_ARCO=' + (has('arco-design-vue') === '1' || has('@arco-design/web-vue') === '1' ? '1' : '0'),
        'HAS_TDESIGN=' + (has('tdesign-vue-next') === '1' || has('tdesign-vue') === '1' ? '1' : '0'),
        'HAS_MUI=' + has('@mui/material'),
        'HAS_CHAKRA=' + (has('chakra-ui') === '1' || has('@chakra-ui/react') === '1' ? '1' : '0'),
        'HAS_TAILWIND=' + has('tailwindcss'),
        'HAS_SASS=' + (has('sass') === '1' || has('node-sass') === '1' || has('dart-sass') === '1' ? '1' : '0'),
        'HAS_LESS=' + (has('less') === '1' || has('less-loader') === '1' ? '1' : '0'),
        'HAS_STYLUS=' + (has('stylus') === '1' || has('stylus-loader') === '1' ? '1' : '0'),
        'HAS_PINIA=' + has('pinia'),
        'HAS_VUEX=' + (has('vuex') === '1' || has('vuex@next') === '1' ? '1' : '0'),
        'HAS_REDUX=' + (has('@reduxjs/toolkit') === '1' || has('redux') === '1' ? '1' : '0'),
        'HAS_ZUSTAND=' + has('zustand'),
        'HAS_MOBX=' + has('mobx'),
        'HAS_JOTAI=' + has('jotai'),
        'HAS_DVA=' + has('dva'),
        'HAS_VITE=' + has('vite'),
        'HAS_WEBPACK=' + has('webpack'),
        'HAS_TS=' + has('typescript'),
        'HAS_VUE_ROUTER=' + has('vue-router'),
        'HAS_REACT_ROUTER=' + (has('react-router') === '1' || has('react-router-dom') === '1' ? '1' : '0'),
        'HAS_PXTOREM=' + has('postcss-pxtorem'),
        'HAS_AMFE=' + has('amfe-flexible'),
        'HAS_LIB_FLEXIBLE=' + has('lib-flexible')
      ];
      console.log(lines.join('\n'));
    } catch (e) {
      // package.json 解析失败：输出空
    }
  " 2>/dev/null)
fi

# 将 PKG_INFO 导入为环境变量
if [ -n "$PKG_INFO" ]; then
  while IFS='=' read -r key value; do
    [ -n "$key" ] && eval "$key=\"$value\""
  done <<< "$PKG_INFO"
fi

# ─── 辅助函数 ────────────────────────────────────────────────
has_dep_flag() {
  # 接收变量名（如 HAS_VUE），返回 0/1
  local val
  eval "val=\${$1:-0}"
  [ "$val" = "1" ]
}

has_file() {
  [ -f "$PROJECT_ROOT/$1" ]
}

# ─── 检测框架 ────────────────────────────────────────────────
FRAMEWORK="unknown"

if has_dep_flag HAS_UNI_APP || has_dep_flag HAS_UNI_VITE || \
   has_file "src/manifest.json" || has_file "src/pages.json"; then
  FRAMEWORK="uni-app"
elif has_dep_flag HAS_TARO_TARO || has_dep_flag HAS_TARO_CLI; then
  FRAMEWORK="taro"
elif has_dep_flag HAS_NEXT; then
  FRAMEWORK="next.js"
elif has_dep_flag HAS_NUXT; then
  FRAMEWORK="nuxt"
elif has_dep_flag HAS_VUE; then
  if [ "$VUE_MAJOR" = "3" ]; then
    FRAMEWORK="vue3"
  elif [ "$VUE_MAJOR" = "2" ] || [ "$VUE_MAJOR" = "1" ]; then
    FRAMEWORK="vue2"
  elif [ -f "$PROJECT_ROOT/node_modules/vue/package.json" ] && \
       grep -q '"3\.' "$PROJECT_ROOT/node_modules/vue/package.json" 2>/dev/null; then
    FRAMEWORK="vue3"
  else
    FRAMEWORK="vue"
  fi
elif has_dep_flag HAS_REACT && has_dep_flag HAS_REACT_DOM; then
  FRAMEWORK="react"
elif has_dep_flag HAS_ANGULAR; then
  FRAMEWORK="angular"
elif has_dep_flag HAS_SVELTE; then
  FRAMEWORK="svelte"
elif [ ! -f "$PROJECT_ROOT/package.json" ]; then
  if has_file "src/pages.json" || has_file "pages.json" || has_file "app.json"; then
    FRAMEWORK="mini-program"
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

if has_dep_flag HAS_ELEMENT_PLUS; then
  UI_FRAMEWORK="element-plus"
elif has_dep_flag HAS_ELEMENT_UI; then
  UI_FRAMEWORK="element-ui"
elif has_dep_flag HAS_ANTV; then
  UI_FRAMEWORK="ant-design-vue"
elif has_dep_flag HAS_ANTD; then
  UI_FRAMEWORK="antd"
elif has_dep_flag HAS_VANT; then
  UI_FRAMEWORK="vant"
elif has_dep_flag HAS_NUTUI; then
  UI_FRAMEWORK="nutui"
elif has_dep_flag HAS_UVIEW; then
  UI_FRAMEWORK="uview"
elif has_dep_flag HAS_ARCO; then
  UI_FRAMEWORK="arco-design"
elif has_dep_flag HAS_TDESIGN; then
  UI_FRAMEWORK="tdesign"
elif has_dep_flag HAS_MUI; then
  UI_FRAMEWORK="mui"
elif has_dep_flag HAS_CHAKRA; then
  UI_FRAMEWORK="chakra-ui"
elif has_dep_flag HAS_TAILWIND; then
  UI_FRAMEWORK="tailwindcss"
fi

# ─── 检测 CSS 预处理器 ─────────────────────────────────────
CSS_PREPROCESSOR="css"

if has_dep_flag HAS_SASS; then
  CSS_PREPROCESSOR="scss"
elif has_dep_flag HAS_LESS; then
  CSS_PREPROCESSOR="less"
elif has_dep_flag HAS_STYLUS; then
  CSS_PREPROCESSOR="stylus"
elif has_dep_flag HAS_TAILWIND; then
  CSS_PREPROCESSOR="tailwind"
fi

# ─── 检测状态管理 ────────────────────────────────────────────
STATE_MANAGEMENT="none"

if has_dep_flag HAS_PINIA; then
  STATE_MANAGEMENT="pinia"
elif has_dep_flag HAS_VUEX; then
  STATE_MANAGEMENT="vuex"
elif has_dep_flag HAS_REDUX; then
  STATE_MANAGEMENT="redux"
elif has_dep_flag HAS_ZUSTAND; then
  STATE_MANAGEMENT="zustand"
elif has_dep_flag HAS_MOBX; then
  STATE_MANAGEMENT="mobx"
elif has_dep_flag HAS_JOTAI; then
  STATE_MANAGEMENT="jotai"
elif has_dep_flag HAS_DVA || { has_dep_flag HAS_TARO_TARO && has_dep_flag HAS_REDUX; }; then
  STATE_MANAGEMENT="dva"
fi

# ─── 检测构建工具 ────────────────────────────────────────────
BUILD_TOOL="unknown"

if has_dep_flag HAS_VITE || has_file "vite.config.ts" || has_file "vite.config.js"; then
  BUILD_TOOL="vite"
elif has_dep_flag HAS_WEBPACK || has_file "webpack.config.js" || has_file "webpack.config.ts"; then
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

if has_dep_flag HAS_TS || has_file "tsconfig.json" || \
   find "$PROJECT_ROOT/src" -maxdepth 3 -name "*.ts" -print -quit 2>/dev/null | grep -q .; then
  TYPESCRIPT="true"
fi

# ─── 检测路由 ────────────────────────────────────────────────
ROUTER="none"

if has_dep_flag HAS_VUE_ROUTER; then
  ROUTER="vue-router"
elif has_dep_flag HAS_REACT_ROUTER; then
  ROUTER="react-router"
elif has_dep_flag HAS_ANGULAR_ROUTER; then
  ROUTER="angular-router"
elif has_dep_flag HAS_NEXT; then
  ROUTER="next-router"
fi

# ─── 检测单位策略（UNIT_STRATEGY）────────────────────────────
UNIT_STRATEGY="px"
UNIT_NOTE="默认 PC/Web 使用 px"
UNIT_WARNING=""

if [ "$FRAMEWORK" = "uni-app" ] || [ "$FRAMEWORK" = "taro" ] || [ "$FRAMEWORK" = "mini-program" ]; then
  UNIT_STRATEGY="rpx"
  UNIT_NOTE="移动端跨端框架，设计稿逻辑 px × 2 → rpx（750 物理基准）"
elif has_file "src/pages.json" || has_file "pages.json" || has_file "app.json"; then
  UNIT_STRATEGY="rpx"
  UNIT_NOTE="检测到小程序配置文件，使用 rpx"
elif has_dep_flag HAS_PXTOREM || has_dep_flag HAS_AMFE || has_dep_flag HAS_LIB_FLEXIBLE; then
  UNIT_STRATEGY="rem"
  UNIT_NOTE="检测到 px→rem 方案，按项目 root font-size 换算"
elif has_dep_flag HAS_VANT || has_dep_flag HAS_UVIEW || has_dep_flag HAS_NUTUI; then
  # 移动 UI 库但非 uni-app：检查 PostCSS/Vite 是否配置适配
  MOBILE_ADAPT_FOUND="false"
  for cfg in postcss.config.js postcss.config.cjs postcss.config.ts .postcssrc.cjs .postcssrc.js .postcssrc.json vite.config.ts vite.config.js vite.config.mjs package.json; do
    if [ -f "$PROJECT_ROOT/$cfg" ] && grep -qE 'pxtorem|px-to-viewport|viewport-units|postcss-px2rem' "$PROJECT_ROOT/$cfg" 2>/dev/null; then
      UNIT_STRATEGY="rem"
      UNIT_NOTE="PostCSS/Vite 含移动端适配插件（$cfg）"
      MOBILE_ADAPT_FOUND="true"
      break
    fi
  done
  if [ "$MOBILE_ADAPT_FOUND" = "false" ]; then
    UNIT_WARNING="检测到移动 UI 库（vant/uview/nutui）但未找到 pxtorem/px-to-viewport 等适配方案。当前 UNIT_STRATEGY=px 可能不正确，请人工确认是否需要 rem。"
  fi
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
echo "UNIT_STRATEGY: $UNIT_STRATEGY"
echo "UNIT_NOTE: $UNIT_NOTE"
if [ -n "$UNIT_WARNING" ]; then
  echo "UNIT_STRATEGY_WARNING: $UNIT_WARNING"
fi
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
