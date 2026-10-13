import 'package:flutter/material.dart';

class SecurityInfoDialog extends StatelessWidget {
  const SecurityInfoDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const SecurityInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.shield_rounded,
                color: Color(0xFF3B82F6),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            '安全规范与边界说明',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '密码学实现与标准',
                content:
                    '• 密钥派生 (KDF)：Argon2id (RFC 9106)，默认 19 MiB 内存，2 轮迭代，16 字节安全随机盐 (CSPRNG)。\n'
                    '• 认证加密 (AEAD)：XChaCha20-Poly1305，24 字节安全随机 Nonce，16 字节 Poly1305 认证标签。\n'
                    '• 关联数据保护 (AAD)：将 56 字节完整头部（版本号、算法标识、KDF 参数、Salt、Nonce）纳入 AAD 校验，彻底杜绝参数静默降级或篡改。',
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: '纯本地与隐私保证',
                content:
                    '• 完全离线：无网络权限，不发起任何网络请求，无远程依赖。\n'
                    '• 零持久化：不保存历史记录，不持久化密码、派生密钥或明文内容。\n'
                    '• 零分析上报：无第三方统计分析、无广告 SDK、不记录敏感日志。',
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: '安全边界与威胁模型披露',
                content:
                    '• 内存生命周期：受 Dart 垃圾回收机制限制，内存中的字符串无法被保证彻底物理清零。完成加解密后建议点击「一键清除」关闭视图状态。\n'
                    '• 设备威胁边界：本工具无法防御已经控制宿主设备的木马病毒、内核级键盘记录器、内存读取器或恶意剪贴板监听程序。\n'
                    '• 剪贴板安全：密文复制到系统剪贴板后，请及时粘贴至笔记软件，避免在不受信任的公共设备上长期残留。',
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('我知道了'),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
