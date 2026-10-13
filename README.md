# x_tool - 轻量、纯本地、跨平台文本加解密工具

`x_tool` 是一个专注于**个人笔记与隐私文本加解密**的轻量、跨平台工具。

---

## 1. 产品定位与核心理念

现代用户通常将日常笔记和文档保存在各类笔记软件或云存储中（如 **Obsidian、Notion、Apple Notes、Markdown 文件、Git 仓库、坚果云、Google Drive** 等）。

`x_tool` **不负责保存笔记内容，仅负责加解密**：

```
[原始私密文本] + [密码] ──(x_tool 加密)──> [标准 ASCII 密文] ──(复制)──> 粘贴到 Obsidian/Notion/云盘
                                                                                 │
[解密还原明文] <──(x_tool 解密)── [输入密码] <──(粘贴密文)──────────────────────┘
```

### 核心原则
- **100% 纯本地运行**：无需网络权限，完全离线运行。
- **零网络依赖与零服务**：不需要账号、登录、服务器、数据库或云端同步。
- **零持久化存储**：不记录历史记录，不自动保存输入文本，不持久化用户密码、派生密钥或明文。
- **零遥测与隐私保护**：无分析统计（Analytics）、无广告 SDK、无崩溃日志上传，不向系统日志打印明文、密码或完整密文。
- **现代化体验**：支持桌面端（双栏布局）与移动端响应式切换，一键粘贴、一键复制、一键清空。

---

## 2. 密码学规范与安全设计

`x_tool` 严格遵循现代应用安全与密码学工程标准，使用成熟、经受实战检验的算法实现：

### 2.1 算法选型
| 功能模块 | 选用算法 / 标准 | 参数规范 |
| :--- | :--- | :--- |
| **密钥派生 (KDF)** | **Argon2id** (RFC 9106) | 内存开销: 19 MiB (19,456 KiB), 迭代轮数: 2, 并行度: 1, 密钥长度: 32 字节 (256-bit) |
| **认证加密 (AEAD)** | **XChaCha20-Poly1305** | 扩展 Nonce: 24 字节 (192-bit), 认证标签: 16 字节 (128-bit Poly1305) |
| **随机数生成 (CSPRNG)** | 系统级安全随机源 (`Random.secure()`) | 每次加密均生成全新独立 16 字节 Salt 与 24 字节 Nonce |
| **关联数据 (AAD)** | 完整 56 字节信封头部绑定 | 将版本号、算法标识、KDF 参数、Salt、Nonce 全部纳入 MAC 校验 |

### 2.2 密文信封结构 (Envelope Format v1)

`x_tool` 采用版本化二进制格式并编码为通用 ASCII Armored 格式：

```
+---------------+-----------+--------+-----------------+-------------------+---------------------+-----------+----------+-----------+----------+---------------+--------------+
| Magic (4B)    | Ver (1B)  | KDF(1B)| KDF Mem (4B BE) | KDF Iter (2B BE)  | KDF Parallel (1B)   | Cipher(1B)| SaltL(1B)| Salt(16B) | NonceL(1B| Nonce (24B)   | Ciphertext(N)| MAC Tag (16B)|
| 0x58 54 4F 4C | 0x01      | 0x01   | 0x00004C00      | 0x0002            | 0x01                | 0x01      | 0x10     | (16 bytes)| 0x18     | (24 bytes)    | (N bytes)    | (16 bytes)   |
+---------------+-----------+--------+-----------------+-------------------+---------------------+-----------+----------+-----------+----------+---------------+--------------+
|<───────────────────────────────────────── 56 字节头部 (AAD 校验区) ──────────────────────────────────────────────>|
```

**文本表现形式 (Armored Block)**：
```text
-----BEGIN XTOOL ENCRYPTED MESSAGE-----
WFRPTAEBAABMAAICARAAAQC2m0...（Base64 编码数据）...
-----END XTOOL ENCRYPTED MESSAGE-----
```
- 解密器兼任解析 Markdown 代码块（如 ````text ... ````）及纯 Base64 格式。
- 当在加密界面粘贴带有 `-----BEGIN XTOOL ENCRYPTED MESSAGE-----` 的内容时，工具会自动切换至「解密」模式。

### 2.3 安全配置档位 (Security Profiles)
`x_tool` 默认提供三级可控防御档位，参数直接固化于密文头部由 AAD 锁定：
- ⚡ **均衡日常 (Balanced)**：`19 MiB` 内存 / 2 轮迭代（单次耗时约 150ms，日常流畅使用首选）。
- 🛡️ **高防安全 (Hardened)**：`64 MiB` 内存 / 3 轮迭代（单次耗时约 500ms，RFC 9106 建议的高对抗档，大幅挤占 GPU 显存）。
- 🔒 **冷存偏执 (Paranoid)**：`128 MiB` 内存 / 4 轮迭代（单次耗时约 1200ms，针对机密凭据冷备的高强度防御）。

### 2.4 安全工具集成
- **CSPRNG 强口令生成器**：支持一键生成 16-32 位高熵随机密码或 4-6 词 Diceware 易记短语（如 `ocean-castle-silver-flame`）。
- **实时密码强度审计**：实时评估熵值，对纯数字短口令主动进行弱密码告警拦截。
- **文本统计与加载示例**：一键加载格式化演示备忘录，实时统计字符数、UTF-8 字节数与行数。

### 2.5 防篡改与 Fail-Closed 机制
- **关联数据（AAD）保护**：信封头部参数（包括 KDF 内存、迭代次数等）与加密载荷紧密结合。攻击者篡改任何参数或头部字节都会导致 Poly1305 MAC 认证失败。
- **强认证失败拒绝**：错误密码、数据损坏或遭篡改时，立即抛出认证失败异常，**绝不返回任何部分明文**。

---

## 3. 安全边界与威胁模型披露

作为严谨的安全工具，我们明确告知用户本产品的安全防御边界与限制：

1. **宿主设备安全性假设**：
   - 本工具无法防御已被恶意软件、内核级键盘记录器（Keylogger）、特权级内存读取器或恶意剪贴板监听程序控制的操作系统环境。
2. **Dart 运行时内存生命周期**：
   - Dart 具有垃圾回收（GC）机制，字符串属于不可变对象（Immutable Strings），无法在语言层面提供 100% 可靠的物理内存清零保证。
   - 工具提供**「一键清除」**按钮，清空文本框与状态，尽可能缩短敏感数据在应用内的可见生命周期。
3. **剪贴板安全**：
   - 复制到系统剪贴板的内容可能被第三方剪贴板历史工具记录，用户在公共或不可信设备上操作时需保持警惕并及时清理剪贴板历史。

---

## 4. 工程架构

项目采用高内聚、低耦合的分层架构设计：

```
lib/
├── crypto/                     # 密码学核心领域层 (独立于 UI，100% 可单元测试)
│   ├── crypto_engine.dart      # 底层 Argon2id 与 XChaCha20-Poly1305 实现
│   ├── crypto_envelope.dart    # 密文信封编解码、AAD 关联数据绑定、版本化解析
│   ├── crypto_exceptions.dart  # 统一异常类型体系 (EmptyPassword, AuthenticationFailed 等)
│   └── crypto_service.dart     # 高层异步门面，利用 Isolate.run 避免阻塞 Flutter UI 渲染
├── ui/                         # 表现层 (响应式 Material 3)
│   ├── screens/
│   │   └── home_screen.dart    # 主交互界面 (桌面端双栏 / 移动端自适应，智能模式识别)
│   ├── theme/
│   │   └── app_theme.dart      # 现代化高对比暗黑/浅色主题
│   └── widgets/
│       └── security_info_dialog.dart # 规范与安全边界披露弹窗
└── main.dart                   # 应用入口
```

- **异步非阻塞**：密钥派生与认证加密通过 Dart `Isolate.run` 派发至后台计算线程，保证高 CPU 密集度计算期间 UI 依然维持 60/120 fps 流畅。

---

## 5. 构建与测试

### 运行环境
- Flutter 3.47+ (Channel Stable)
- Dart 3.13+

### 单元测试与分析器检查
本项目包含全面的自动化测试，覆盖 Unicode 任意字符、空文本、换行符、损坏密文、错误密码、参数篡改防护及 UI 交互测试：

```bash
# 运行静态代码分析
flutter analyze

# 运行自动化测试套件
flutter test
```

### 构建目标二进制

```bash
# 本地构建 Windows Release 版本
flutter build windows --release

# 本地构建 Android Release APK
flutter build apk --release
```

---

## 6. 自动化打包与发布 (CI/CD)

本项目配置了 GitHub Actions 自动化工作流（`.github/workflows/build-and-release.yml`）：

- **常规构建与 Artifacts 下载**：
  - 每次推送到 `main` / `master` 分支或提交 PR 时，GitHub Actions 会自动运行单元测试并编译 **Windows x64 Release ZIP** 与 **Android Release APK**。
  - 构建产物可在 GitHub Actions 运行记录的 **Artifacts** 区域直接下载试用。
- **自动化发布 Release**：
  - 推送版本标签（Tag，如 `git tag v1.0.0 && git push origin v1.0.0`）时，工作流会自动创建 GitHub Release 并上传 Windows 与 Android 的发布包。
- **手动触发**：
  - 支持在 GitHub Actions 页面通过 **Run workflow** 手动触发打包流程。

---

## 7. 开源协议

本项目基于 MIT License 开源。
