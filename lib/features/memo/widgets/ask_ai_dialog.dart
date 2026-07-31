import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AskAiDialog extends StatefulWidget {
  final Future<String> Function(String question) onAsk;

  const AskAiDialog({super.key, required this.onAsk});

  @override
  State<AskAiDialog> createState() => _AskAiDialogState();
}

class _AskAiDialogState extends State<AskAiDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _response;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (_controller.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _response = null;
    });

    try {
      final response = await widget.onAsk(_controller.text);
      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '오류: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF4A90E2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ask AI',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 질문 입력
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '질문을 입력하세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _ask(),
              ),
              const SizedBox(height: 12),

              // 질문 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _ask,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: Text(_isLoading ? '생각 중...' : '질문하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              // 응답
              if (_response != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'AI 응답',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    // 복사 버튼
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _response!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('복사됨'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _response!,
                      style: const TextStyle(fontSize: 13, height: 1.6),
                    ),
                  ),
                ),
              ],

              // 에러
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
