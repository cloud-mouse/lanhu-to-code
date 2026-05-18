#!/usr/bin/env node

/**
 * lanhu-to-code skill 安装/更新/卸载脚本
 *
 * 用法：
 *   node install.js              # 安装或更新
 *   node install.js --uninstall  # 卸载
 *   node install.js --version    # 查看版本
 */

const fs = require('fs')
const path = require('path')
const os = require('os')

const SKILL_NAME = 'lanhu-to-code'
const CLAUDE_SKILLS_DIR = path.join(os.homedir(), '.claude', 'skills')
const TARGET_DIR = path.join(CLAUDE_SKILLS_DIR, SKILL_NAME)
const SOURCE_DIR = path.resolve(__dirname)

// 版本号（与 package.json 同步）
const VERSION = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'), 'utf8')).version

// 安装记录文件
const INSTALL_RECORD = path.join(TARGET_DIR, '.install-record.json')

// ─── 命令分发 ────────────────────────────────────────────────

const command = process.argv[2]

if (command === '--version' || command === '-v') {
  console.log(`lanhu-to-code v${VERSION}`)
  process.exit(0)
}

if (command === '--uninstall' || command === '-u') {
  uninstall()
  process.exit(0)
}

install()

// ─── 安装 / 更新 ────────────────────────────────────────────

function install() {
  console.log(`\n🎨 lanhu-to-code skill v${VERSION}\n`)

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
    // 读取安装记录
    const existingVersion = getInstalledVersion()
    if (existingVersion) {
      if (existingVersion === VERSION) {
        console.log(`✅ 已安装 v${VERSION}（最新版）`)
      } else {
        console.log(`📦 更新 v${existingVersion} → v${VERSION}`)
      }
    }

    const isSymlink = fs.lstatSync(TARGET_DIR).isSymbolicLink()
    if (isSymlink) {
      const linkTarget = fs.readlinkSync(TARGET_DIR)
      if (linkTarget === SOURCE_DIR) {
        // 符号链接指向当前源码，更新安装记录即可
        writeInstallRecord()
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
    writeInstallRecord()
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

  // --- 备份已有安装（非符号链接时） ---
  function backupExisting() {
    if (!fs.existsSync(TARGET_DIR)) return
    const isSymlink = fs.lstatSync(TARGET_DIR).isSymbolicLink()
    if (!isSymlink) {
      const backupDir = TARGET_DIR + '.bak'
      if (fs.existsSync(backupDir)) {
        fs.rmSync(backupDir, { recursive: true, force: true })
      }
      fs.renameSync(TARGET_DIR, backupDir)
      console.log(`📦 已备份旧安装到: ${backupDir}`)
    }
  }

  try {
    // 尝试创建符号链接（优先）
    try {
      if (fs.existsSync(TARGET_DIR)) {
        backupExisting()
      }
      if (fs.existsSync(TARGET_DIR)) {
        fs.rmSync(TARGET_DIR, { recursive: true, force: true })
      }
      fs.symlinkSync(SOURCE_DIR, TARGET_DIR, 'junction')
      console.log(`🔗 创建符号链接: ${TARGET_DIR} → ${SOURCE_DIR}`)
    } catch (e) {
      // 符号链接失败，回退到文件复制
      if (fs.existsSync(TARGET_DIR)) {
        backupExisting()
      }
      fs.mkdirSync(TARGET_DIR, { recursive: true })
      copyRecursive(SOURCE_DIR, TARGET_DIR)
      console.log(`📋 复制文件到: ${TARGET_DIR}`)
    }

    // 写入安装记录
    writeInstallRecord()

    console.log(`\n✅ 安装成功！v${VERSION}\n`)
    console.log(`使用方式：`)
    console.log(`  1. 在 Claude Code 中说 "还原这个蓝湖设计稿"`)
    console.log(`  2. 或提供蓝湖链接：/lanhu-to-code https://lanhuapp.com/...`)
    console.log(`  3. 或提供设计图图片路径\n`)
    console.log(`其他命令：`)
    console.log(`  node install.js --version     查看版本`)
    console.log(`  node install.js --uninstall   卸载\n`)

  } catch (err) {
    console.error(`❌ 安装失败: ${err.message}`)
    console.error(`\n手动安装方式：`)
    console.error(`  cp -r ${SOURCE_DIR} ${TARGET_DIR}`)
    process.exit(1)
  }
}

// ─── 卸载 ────────────────────────────────────────────────────

function uninstall() {
  console.log(`\n🗑️  卸载 lanhu-to-code\n`)

  if (!fs.existsSync(TARGET_DIR)) {
    console.log(`⚠️  未找到安装目录: ${TARGET_DIR}`)
    console.log(`   可能未安装或已卸载。\n`)
    return
  }

  try {
    const isSymlink = fs.lstatSync(TARGET_DIR).isSymbolicLink()
    const version = getInstalledVersion()

    fs.rmSync(TARGET_DIR, { recursive: true, force: true })

    if (isSymlink) {
      console.log(`✅ 已移除符号链接: ${TARGET_DIR}`)
    } else {
      console.log(`✅ 已删除目录: ${TARGET_DIR}`)
    }
    console.log(`   已卸载${version ? ` v${version}` : ''}\n`)
  } catch (err) {
    console.error(`❌ 卸载失败: ${err.message}`)
    console.error(`   请手动删除: ${TARGET_DIR}\n`)
    process.exit(1)
  }
}

// ─── 安装记录 ────────────────────────────────────────────────

function writeInstallRecord() {
  // 符号链接模式下不写入记录文件，避免污染源码目录
  if (fs.existsSync(TARGET_DIR) && fs.lstatSync(TARGET_DIR).isSymbolicLink()) {
    return
  }
  const record = {
    version: VERSION,
    installedAt: new Date().toISOString(),
    source: SOURCE_DIR,
  }
  const recordPath = path.join(TARGET_DIR, '.install-record.json')
  try {
    fs.writeFileSync(recordPath, JSON.stringify(record, null, 2), 'utf8')
  } catch (e) {
    // 写入失败不影响安装
  }
}

function getInstalledVersion() {
  try {
    const recordPath = path.join(TARGET_DIR, '.install-record.json')
    if (fs.existsSync(recordPath)) {
      const record = JSON.parse(fs.readFileSync(recordPath, 'utf8'))
      return record.version
    }
  } catch (e) {
    // 忽略读取错误
  }
  return null
}
