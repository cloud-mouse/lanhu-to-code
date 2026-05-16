#!/usr/bin/env node

/**
 * lanhu-to-code skill 安装脚本
 *
 * 将 skill 文件安装到 ~/.claude/skills/lanhu-to-code/
 *
 * 使用方式：
 *   npx lanhu-to-code          # 直接安装
 *   npm install -g lanhu-to-code && lanhu-to-code  # 全局安装后执行
 *   node install.js            # 从源码目录执行
 */

const fs = require('fs')
const path = require('path')
const os = require('os')
const { execSync } = require('child_process')

const SKILL_NAME = 'lanhu-to-code'
const CLAUDE_SKILLS_DIR = path.join(os.homedir(), '.claude', 'skills')
const TARGET_DIR = path.join(CLAUDE_SKILLS_DIR, SKILL_NAME)

// 确定源目录（优先用 npm 包目录，兜底用当前脚本所在目录）
const SOURCE_DIR = path.resolve(__dirname)

console.log(`\n🎨 lanhu-to-code skill 安装器\n`)

// --- 检查源目录有效性 ---
const skillFile = path.join(SOURCE_DIR, 'SKILL.md')
if (!fs.existsSync(skillFile)) {
  console.error(`❌ 未找到 SKILL.md，请确认包完整性: ${skillFile}`)
  process.exit(1)
}

// --- 创建目标目录 ---
if (!fs.existsSync(CLAUDE_SKILLS_DIR)) {
  fs.mkdirSync(CLAUDE_SKILLS_DIR, { recursive: true })
  console.log(`📁 创建目录: ${CLAUDE_SKILLS_DIR}`)
}

// --- 检查是否已安装 ---
if (fs.existsSync(TARGET_DIR)) {
  const isSymlink = fs.lstatSync(TARGET_DIR).isSymbolicLink()
  if (isSymlink) {
    const linkTarget = fs.readlinkSync(TARGET_DIR)
    if (linkTarget === SOURCE_DIR) {
      console.log(`✅ 已安装（符号链接）: ${TARGET_DIR} → ${SOURCE_DIR}`)
      console.log(`\n使用方式：在 Claude Code 中说 "还原这个蓝湖设计稿" 或直接提供蓝湖链接/设计图\n`)
      return
    }
  }
  console.log(`⚠️  目录已存在: ${TARGET_DIR}`)
  console.log(`   将更新文件...`)
}

// --- 安装策略：源码目录 == 目标目录时跳过 ---
if (SOURCE_DIR === TARGET_DIR) {
  console.log(`✅ 已在 skill 目录中运行，无需安装`)
  console.log(`\n使用方式：在 Claude Code 中说 "还原这个蓝湖设计稿" 或直接提供蓝湖链接/设计图\n`)
  return
}

// --- 复制文件 ---
function copyRecursive(src, dest) {
  const stat = fs.statSync(src)
  if (stat.isDirectory()) {
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true })
    }
    for (const entry of fs.readdirSync(src)) {
      if (entry === 'node_modules' || entry === '.git' || entry === 'package.json' ||
          entry === 'install.js' || entry === 'README.md' || entry === 'LICENSE') {
        continue
      }
      copyRecursive(path.join(src, entry), path.join(dest, entry))
    }
  } else {
    fs.copyFileSync(src, dest)
  }
}

try {
  // 尝试创建符号链接（优先）
  try {
    if (fs.existsSync(TARGET_DIR)) {
      fs.rmSync(TARGET_DIR, { recursive: true, force: true })
    }
    fs.symlinkSync(SOURCE_DIR, TARGET_DIR, 'junction')
    console.log(`🔗 创建符号链接: ${TARGET_DIR} → ${SOURCE_DIR}`)
  } catch (e) {
    // 符号链接失败，回退到文件复制
    if (fs.existsSync(TARGET_DIR)) {
      fs.rmSync(TARGET_DIR, { recursive: true, force: true })
    }
    fs.mkdirSync(TARGET_DIR, { recursive: true })
    copyRecursive(SOURCE_DIR, TARGET_DIR)
    console.log(`📋 复制文件到: ${TARGET_DIR}`)
  }

  console.log(`\n✅ 安装成功！\n`)
  console.log(`使用方式：`)
  console.log(`  1. 在 Claude Code 中说 "还原这个蓝湖设计稿"`)
  console.log(`  2. 或提供蓝湖链接：/lanhu-to-code https://lanhuapp.com/...`)
  console.log(`  3. 或提供设计图图片路径\n`)

} catch (err) {
  console.error(`❌ 安装失败: ${err.message}`)
  console.error(`\n手动安装方式：`)
  console.error(`  cp -r ${SOURCE_DIR} ${TARGET_DIR}`)
  process.exit(1)
}
