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
  bool _isMarkingAllRead = false;

  // 선택 삭제 모드
  bool _selectMode = false;
  final Set<String> _checked = {};
  bool _isDeleting = false;

  void _exitSelectMode() => setState(() {
    _selectMode = false;
    _checked.clear();
  });

  Future<void> _deleteChecked() async {
    final count = _checked.length;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메일 삭제'),
        content: Text(
          '선택한 메일 $count통을 삭제할까요?\n'
          'Gmail 휴지통으로 이동하며, 30일 안에는 Gmail에서 복구할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final deleted = await ref
        .read(mailMessagesProvider.notifier)
        .trash(Set.of(_checked));
    if (!mounted) return;
    setState(() => _isDeleting = false);
    _exitSelectMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted == count
              ? '메일 $deleted통을 삭제했습니다'
              : '메일 $count통 중 $deleted통만 삭제했습니다',
        ),
        backgroundColor: deleted == count ? null : Colors.red,
      ),
    );
  }

  Widget _buildSelectHeader(List<MailMessage> messages) {
    final allChecked =
        messages.isNotEmpty && messages.every((m) => _checked.contains(m.id));
    return Row(
      children: [
        Checkbox(
          value: allChecked,
          visualDensity: VisualDensity.compact,
          onChanged: (v) => setState(() {
            if (v == true) {
              _checked.addAll(messages.map((m) => m.id));
            } else {
              _checked.clear();
            }
          }),
        ),
        Expanded(
          child: Text(
            '${_checked.length}개 선택',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline, size: 18),
          tooltip: '삭제',
          color: Colors.red,
          onPressed: _checked.isEmpty || _isDeleting ? null : _deleteChecked,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: '선택 취소',
          onPressed: _isDeleting ? null : _exitSelectMode,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Future<void> _markAllAsRead() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모두 읽음'),
        content: const Text('받은편지함의 안 읽은 메일을 모두 읽음 처리할까요?\nGmail에도 반영됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('모두 읽음'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isMarkingAllRead = true);
    final count = await ref.read(mailMessagesProvider.notifier).markAllAsRead();
    if (!mounted) return;
    setState(() => _isMarkingAllRead = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == null
              ? '읽음 처리에 실패했습니다. 다시 시도해주세요'
              : count == 0
              ? '안 읽은 메일이 없습니다'
              : '메일 $count통을 읽음 처리했습니다',
        ),
        backgroundColor: count == null ? Colors.red : null,
      ),
    );
  }

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
              '메일 서비스를 이용하려면\n로그인이 필요합니다',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => showMailLoginDialog(context),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('로그인'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
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
          child: _selectMode
              ? _buildSelectHeader(messagesAsync.value ?? const [])
              : Row(
                  children: [
                    const Text(
                      '받은편지함',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 계정 이메일 — Expanded로 감싸서 남은 공간만 사용
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, _) {
                          final account = ref.watch(mailAccountProvider).value;
                          if (account == null) return const SizedBox();
                          return Text(
                            account.email,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    // // 계정 관리 버튼
                    // IconButton(
                    //   icon: const Icon(Icons.manage_accounts, size: 18),
                    //   tooltip: '계정 관리',
                    //   onPressed: () => showMailLoginDialog(context),
                    //   padding: EdgeInsets.zero,
                    //   constraints: const BoxConstraints(),
                    // ),
                    // const SizedBox(width: 8),
                    IconButton(
                      icon: _isMarkingAllRead
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all, size: 18),
                      tooltip: '모두 읽음',
                      onPressed: _isMarkingAllRead ? null : _markAllAsRead,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.checklist, size: 18),
                      tooltip: '선택해서 삭제',
                      onPressed: () => setState(() => _selectMode = true),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
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
              child: Text(
                '$e',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  final msg = messages[index];
                  final selectedId = ref.watch(selectedMailProvider)?.id;
                  if (_selectMode) {
                    return _MailListItem(
                      message: msg,
                      isSelected: _checked.contains(msg.id),
                      checked: _checked.contains(msg.id),
                      onTap: () => setState(() {
                        if (!_checked.remove(msg.id)) _checked.add(msg.id);
                      }),
                    );
                  }
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

  /// 선택 모드일 때 체크 여부 (null이면 체크박스 없음)
  final bool? checked;

  const _MailListItem({
    required this.message,
    required this.isSelected,
    required this.onTap,
    this.checked,
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
        child: Row(
          children: [
            if (checked != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Checkbox(
                  value: checked,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => onTap(),
                ),
              ),
            Expanded(
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
                            fontWeight: message.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(message.date),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
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
