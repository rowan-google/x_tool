import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../crypto/password_generator.dart';

class PasswordGeneratorDialog extends StatefulWidget {
  final void Function(String password) onPasswordSelected;

  const PasswordGeneratorDialog({
    super.key,
    required this.onPasswordSelected,
  });

  static void show(BuildContext context, {required void Function(String password) onSelected}) {
    showDialog(
      context: context,
      builder: (context) => PasswordGeneratorDialog(onPasswordSelected: onSelected),
    );
  }

  @override
  State<PasswordGeneratorDialog> createState() => _PasswordGeneratorDialogState();
}

class _PasswordGeneratorDialogState extends State<PasswordGeneratorDialog> {
  bool _isPassphrase = false;
  int _length = 16;
  int _wordCount = 4;
  late String _generatedPassword;

  @override
  void initState() {
    super.initState();
    _regenerate();
  }

  void _regenerate() {
    setState(() {
      if (_isPassphrase) {
        _generatedPassword = PasswordGenerator.generatePassphrase(wordCount: _wordCount);
      } else {
        _generatedPassword = PasswordGenerator.generateRandomPassword(length: _length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.casino_outlined, color: Color(0xFF3B82F6), size: 26),
          SizedBox(width: 10),
          Text(
            '安全强口令生成器',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.password_rounded),
                  label: Text('高熵复杂密码'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.short_text_rounded),
                  label: Text('易记短语 (Diceware)'),
                ),
              ],
              selected: {_isPassphrase},
              onSelectionChanged: (set) {
                setState(() {
                  _isPassphrase = set.first;
                  _regenerate();
                });
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _generatedPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '重新生成',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF3B82F6)),
                    onPressed: _regenerate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!_isPassphrase)
              Row(
                children: [
                  const Text('长度: ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _length.toDouble(),
                      min: 10,
                      max: 32,
                      divisions: 22,
                      label: '$_length 字符',
                      onChanged: (val) {
                        setState(() {
                          _length = val.round();
                          _regenerate();
                        });
                      },
                    ),
                  ),
                  Text('$_length 位', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              )
            else
              Row(
                children: [
                  const Text('单词数: ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _wordCount.toDouble(),
                      min: 3,
                      max: 6,
                      divisions: 3,
                      label: '$_wordCount 单词',
                      onChanged: (val) {
                        setState(() {
                          _wordCount = val.round();
                          _regenerate();
                        });
                      },
                    ),
                  ),
                  Text('$_wordCount 个', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            const SizedBox(height: 6),
            const Text(
              '提示：由系统 CSPRNG 安全随机数驱动，具备极高信息熵，可有效免疫离线暴破。',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('复制'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _generatedPassword));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('已复制密码到剪贴板'), duration: Duration(seconds: 1)),
            );
          },
        ),
        FilledButton(
          onPressed: () {
            widget.onPasswordSelected(_generatedPassword);
            Navigator.of(context).pop();
          },
          child: const Text('填入密码输入框'),
        ),
      ],
    );
  }
}
