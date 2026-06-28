import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/mail_provider.dart';
import '../models/mail_message.dart';
import '../widgets/mail_login_dialog.dart';

class MailListView extends ConsumerStatefulWidget {
  const MailListView({super.key});

  @override
  ConsumerState<MailListView> createState() => _MailListViewState();
}

class _MailListViewState extends ConsumerState<MailListView> {
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

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
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    await ref.read(mailMessagesProvider.notifier).loadMore();
    if (mounted) setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(mailAccountProvider);

    return accountAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (account) {
        if (account == null) {
          return _buildNotLoggedIn();
        }
        return _buildMailList();
      },
    );
  }

  Widget _buildNotLoggedIn() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text(
              '로그인이 필요합니다',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showMailLoginDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('로그인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMailList() {
    final messagesAsync = ref.watch(mailMessagesProvider);

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: Row(
            children: [
              const Text(
                '받은편지함',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

        // 목록
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('$e',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const Center(
                  child: Text('메일이 없어요', style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    return _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  final msg = messages[index];
                  final selectedId = ref.watch(selectedMailProvider)?.id;
                  return _MailListItem(
                    message: msg,
                    isSelected: msg.id == selectedId,
                    onTap: () =>
                        ref.read(selectedMailProvider.notifier).select(msg),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

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
          border: const Border(
            bottom: BorderSide(color: Color(0xFFEEEEEE)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                      fontWeight:
                          message.isRead ? FontWeight.normal : FontWeight.bold,
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
                fontWeight:
                    message.isRead ? FontWeight.normal : FontWeight.w600,
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
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }
}
