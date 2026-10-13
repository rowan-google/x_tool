import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../crypto/crypto_envelope.dart';
import '../../crypto/crypto_exceptions.dart';
import '../../crypto/crypto_service.dart';
import '../../main.dart';
import '../widgets/password_generator_dialog.dart';
import '../widgets/security_info_dialog.dart';

enum CryptoMode { encrypt, decrypt }

enum SecurityLevel {
  balanced('均衡日常', '19MB / 2轮 (毫秒级响应)', CryptoParameters.balanced),
  hardened('高防安全', '64MB / 3轮 (抗专业GPU农场)', CryptoParameters.hardened),
  paranoid('冷存偏执', '128MB / 4轮 (极端冷备重装防御)', CryptoParameters.paranoid);

  final String label;
  final String description;
  final CryptoParameters parameters;

  const SecurityLevel(this.label, this.description, this.parameters);
}

class HomeScreen extends StatefulWidget {
  final CryptoService? cryptoService;

  const HomeScreen({super.key, this.cryptoService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CryptoService _cryptoService;

  CryptoMode _mode = CryptoMode.encrypt;
  SecurityLevel _securityLevel = SecurityLevel.balanced;

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _justCopied = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _cryptoService = widget.cryptoService ?? const CryptoService(useIsolate: true);
    _inputController.addListener(_onInputChanged);
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _passwordController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {});
    final text = _inputController.text;
    // Auto-detect armored message when in encrypt mode
    if (_mode == CryptoMode.encrypt && CryptoEnvelope.isArmoredText(text)) {
      setState(() {
        _mode = CryptoMode.decrypt;
        _errorMessage = null;
        _successMessage = '已智能识别密文并切换至「文本解密」模式';
      });
    }
  }

  void _clearAll() {
    setState(() {
      _inputController.clear();
      _passwordController.clear();
      _outputController.clear();
      _errorMessage = null;
      _successMessage = '所有输入、密码和结果已全部清空';
    });
  }

  void _loadSampleNote() {
    const sample = '''# 2026 个人机密财务备忘录 🛡️
- 离线助记词：alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima
- 安全存储节点 IP: 192.168.1.100 (SSH 端口: 22022)
- 备用凭据口令: K9#mQ!2z\$pL8@vR7''';

    setState(() {
      _inputController.text = sample;
      if (_passwordController.text.isEmpty) {
        _passwordController.text = 'DemoSafePass2026!';
      }
      _errorMessage = null;
      _successMessage = '已加载示例私密文本，点击下方「立即加密」即可体验';
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _inputController.text = data.text!;
        _errorMessage = null;
      });
      if (CryptoEnvelope.isArmoredText(data.text!)) {
        setState(() {
          _mode = CryptoMode.decrypt;
          _successMessage = '已粘贴密文并切换至解密模式';
        });
      }
    }
  }

  Future<void> _copyOutputToClipboard() async {
    final text = _outputController.text;
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    setState(() {
      _justCopied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _justCopied = false);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text('已成功复制到系统剪贴板，可粘贴至 Obsidian / 备忘录'),
          ],
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _execute() async {
    final input = _inputController.text;
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _errorMessage = '请输入解密所需的强密码';
        _successMessage = null;
      });
      return;
    }

    if (_mode == CryptoMode.decrypt && input.trim().isEmpty) {
      setState(() {
        _errorMessage = '请输入待解密的密文';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (_mode == CryptoMode.encrypt) {
        final result = await _cryptoService.encrypt(
          plaintext: input,
          password: password,
          parameters: widget.cryptoService != null &&
                  widget.cryptoService!.defaultParameters != const CryptoParameters()
              ? widget.cryptoService!.defaultParameters
              : _securityLevel.parameters,
        );
        if (!mounted) return;
        setState(() {
          _outputController.text = result;
          _successMessage = '加密完成！密文已生成（${_securityLevel.label}）';
        });
      } else {
        final result = await _cryptoService.decrypt(
          armoredOrBase64: input,
          password: password,
        );
        if (!mounted) return;
        setState(() {
          _outputController.text = result;
          _successMessage = '解密成功！原文已安全还原';
        });
      }
    } on CryptoException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '处理失败: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 14) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[a-zA-Z]').hasMatch(password)) score++;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) score++;
    return score; // 0..5
  }

  bool _isPasswordWeak(String password) {
    if (password.isEmpty) return false;
    if (password.length < 8) return true;
    if (RegExp(r'^\d+$').hasMatch(password)) return true; // pure digits
    return false;
  }

  Color _getPasswordStrengthColor(int score) {
    if (score <= 1) return const Color(0xFFEF4444);
    if (score <= 3) return const Color(0xFFF59E0B);
    if (score == 4) return const Color(0xFF3B82F6);
    return const Color(0xFF10B981);
  }

  String _getPasswordStrengthText(int score) {
    if (score == 0) return '未输入';
    if (score <= 1) return '极弱 (高风险)';
    if (score <= 3) return '一般';
    if (score == 4) return '良好';
    return '极强 (推荐)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 880;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF3B82F6),
                    size: 26,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'x_tool',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'v1.0',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '纯本地隐私文本加解密',
                  style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8)),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
                  SizedBox(width: 5),
                  Text(
                    '纯本地 · 零泄露',
                    style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? '切换至浅色模式' : '切换至暗黑模式',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () {
              themeModeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            tooltip: '安全规范与边界说明',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => SecurityInfoDialog.show(context),
          ),
          IconButton(
            tooltip: '一键清除全部状态 (缩短敏感数据生命周期)',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearAll,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildModeSelector(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildAlertBanner(_errorMessage!, isError: true),
                  if (_successMessage != null) _buildAlertBanner(_successMessage!, isError: false),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildInputPanel()),
                        const SizedBox(width: 20),
                        Expanded(child: _buildOutputPanel()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildInputPanel(),
                        const SizedBox(height: 20),
                        _buildOutputPanel(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              mode: CryptoMode.encrypt,
              title: '文本加密 (Encrypt)',
              icon: Icons.lock_outline_rounded,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTabButton(
              mode: CryptoMode.decrypt,
              title: '文本解密 (Decrypt)',
              icon: Icons.lock_open_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required CryptoMode mode,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _mode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() {
          _mode = mode;
          _errorMessage = null;
          _successMessage = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(String message, {required bool isError}) {
    final bgColor = isError ? const Color(0xFFEF4444).withValues(alpha: 0.12) : const Color(0xFF10B981).withValues(alpha: 0.12);
    final textColor = isError ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: textColor),
            onPressed: () {
              setState(() {
                if (isError) {
                  _errorMessage = null;
                } else {
                  _successMessage = null;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    final isEncrypt = _mode == CryptoMode.encrypt;
    final hint = isEncrypt ? '输入或粘贴需要加密的私密笔记/文本...' : '粘贴带有 -----BEGIN XTOOL ENCRYPTED MESSAGE----- 的密文...';

    final text = _inputController.text;
    final charCount = text.length;
    final byteCount = utf8.encode(text).length;
    final lineCount = text.isEmpty ? 0 : text.split('\n').length;

    final strength = _calculatePasswordStrength(_passwordController.text);
    final isWeak = _isPasswordWeak(_passwordController.text);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isEncrypt ? Icons.edit_note_rounded : Icons.lock_clock_outlined,
                      size: 20,
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEncrypt ? '明文输入' : '密文输入',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isEncrypt && text.isEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                        label: const Text('示例文本'),
                        onPressed: _loadSampleNote,
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.content_paste_rounded, size: 15),
                      label: const Text('粘贴'),
                      onPressed: _pasteFromClipboard,
                    ),
                    IconButton(
                      tooltip: '清空输入',
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _inputController.clear(),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              minLines: 8,
              maxLines: 12,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: hint,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '统计: $charCount 字符 · $byteCount 字节 · $lineCount 行',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                ),
              ],
            ),
            if (isEncrypt) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF3B82F6)),
                  SizedBox(width: 6),
                  Text(
                    '安全防护配置档位',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSecurityProfileSelector(),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key_rounded, size: 16, color: Color(0xFF3B82F6)),
                    SizedBox(width: 6),
                    Text(
                      '加密密码',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.casino_outlined, size: 15),
                  label: const Text('随机强口令'),
                  onPressed: () {
                    PasswordGeneratorDialog.show(
                      context,
                      onSelected: (generated) {
                        setState(() {
                          _passwordController.text = generated;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: '输入解密所需的强口令 (建议 12 位以上或使用密码短语)',
                prefixIcon: const Icon(Icons.password_rounded, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _isPasswordVisible ? '隐藏密码' : '显示密码',
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    if (_passwordController.text.isNotEmpty)
                      IconButton(
                        tooltip: '清空密码',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          setState(() {
                            _passwordController.clear();
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('强度: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    _getPasswordStrengthText(strength),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getPasswordStrengthColor(strength),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_passwordController.text.length} 字符',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: strength / 5.0,
                  minHeight: 4,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(_getPasswordStrengthColor(strength)),
                ),
              ),
              if (isWeak && isEncrypt) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFEF4444)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '警告：检测到简短或纯数字口令，极易被离线字典穷举，建议点右上角「随机强口令」。',
                          style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _execute,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text('Argon2id 派生中 (${_securityLevel.parameters.memoryKiB ~/ 1024}MB)...'),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isEncrypt ? Icons.lock_outline : Icons.lock_open_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(isEncrypt ? '立即加密并生成密文' : '立即解密还原明文'),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityProfileSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: SecurityLevel.values.map((level) {
          final isSelected = _securityLevel == level;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _securityLevel = level),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 18,
                    color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    level.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF3B82F6) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      level.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOutputPanel() {
    final isEncrypt = _mode == CryptoMode.encrypt;
    final hasOutput = _outputController.text.isNotEmpty;

    final outputText = _outputController.text;
    final charCount = outputText.length;
    final byteCount = utf8.encode(outputText).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isEncrypt ? Icons.vpn_key_outlined : Icons.description_outlined,
                      size: 20,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEncrypt ? '密文结果' : '解密明文',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (hasOutput)
                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        icon: Icon(_justCopied ? Icons.check_circle_rounded : Icons.copy_rounded, size: 16),
                        label: Text(_justCopied ? '已复制！' : '复制结果'),
                        onPressed: _copyOutputToClipboard,
                      ),
                      IconButton(
                        tooltip: '清空输出',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _outputController.clear(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _outputController,
              readOnly: true,
              minLines: 8,
              maxLines: 12,
              style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: isEncrypt ? '加密后的密文将在此处显示，可一键复制到 Obsidian/Notion/备忘录...' : '解密后的明文将在此处显示...',
              ),
            ),
            if (hasOutput) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '结果统计: $charCount 字符 · $byteCount 字节',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 16, color: Color(0xFF3B82F6)),
                      SizedBox(width: 6),
                      Text(
                        '密码学协议保障',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• KDF: Argon2id (RFC 9106, 16B CSPRNG 盐)\n'
                    '• AEAD: XChaCha20-Poly1305 (24B Nonce, 16B 认证标签)\n'
                    '• AAD: 56 字节完整头部参数防静默篡改与防降级\n'
                    '• 本地状态：支持一键彻底清空输入框与内存缓存',
                    style: TextStyle(fontSize: 11, height: 1.4, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            if (hasOutput) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  icon: Icon(_justCopied ? Icons.check_circle_rounded : Icons.content_copy_rounded, size: 18),
                  label: Text(_justCopied ? '已复制到剪贴板！' : '复制到系统剪贴板'),
                  onPressed: _copyOutputToClipboard,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
