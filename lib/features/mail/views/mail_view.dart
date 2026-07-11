import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import '../models/mail_message.dart';
import '../widgets/mail_login_dialog.dart';

class MailView extends ConsumerStatefulWidget {
  const MailView({super.key});

  @override
  ConsumerState<MailView> createState() => _MailViewState();
}

class _MailViewState extends ConsumerState<MailView> {
  MailMessage? _selectedMessage;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(mailMessagesProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(mailAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (account) {
        if (account == null) {
          return _buildNotLoggedInView();
        }
        return _buildMailView();
      },
    );
  }

  Widget _buildNotLoggedInView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            '메일 서비스를 이용하려면\n로그인이 필요합니다',
            style: TextStyle(fontSize: 15, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => showMailLoginDialog(context),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('로그인'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMailView() {
    final messagesAsync = ref.watch(mailMessagesProvider);

    return Row(
      children: [
        // 좌측: 메일 목록
        Container(
          width: 250,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
                ),
                child: Row(
                  children: [
                    const Text(
                      '받은편지함',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: '새로고침',
                      onPressed: () =>
                          ref.read(mailMessagesProvider.notifier).refresh(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 메일 목록
              Expanded(
                child: messagesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          '$e',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          '메일이 없어요',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isSelected = _selectedMessage == msg;
                        return _MailListItem(
                          message: msg,
                          isSelected: isSelected,
                          onTap: () => setState(() => _selectedMessage = msg),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // 우측: 메일 내용
        Expanded(
          child: _selectedMessage != null
              ? _MailDetailView(message: _selectedMessage!)
              : const Center(
                  child: Text(
                    '메일을 선택하세요',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
        ),
      ],
    );
  }
}

// 메일 목록 아이템
class _MailListItem extends StatelessWidget {
  final MailMessage message;
  final bool isSelected;
  final VoidCallback onTap;

  const _MailListItem({
    required this.message,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 읽음 여부 표시
                if (!message.isRead)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    message.from,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: message.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(message.date),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              message.subject,
              style: TextStyle(
                fontSize: 12,
                fontWeight: message.isRead
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (message.preview.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                message.preview,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }
}

// 메일 상세 뷰
class _MailDetailView extends StatelessWidget {
  final MailMessage message;

  const _MailDetailView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          Text(
            message.subject,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 보낸사람 / 날짜
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF4A90E2),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.from,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${message.date.year}.${message.date.month}.${message.date.day} '
                      '${message.date.hour.toString().padLeft(2, '0')}:${message.date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // 본문
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                message.preview.isEmpty ? '(내용 없음)' : message.preview,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
