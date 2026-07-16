import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// In-app notification center, shared by every role (Phase 1 skeleton).
/// Lists `/users/notifications`, supports tap-to-mark-read and pull-to-refresh.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(dioProvider).get('/users/notifications');
      _items = (res.data as List).cast<Map<String, dynamic>>();
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not load notifications';
      });
    }
  }

  Future<void> _markRead(Map<String, dynamic> n) async {
    if (n['read_at'] != null) return;
    try {
      await ref.read(dioProvider).patch('/users/notifications/${n['id']}/read');
      setState(() => n['read_at'] = DateTime.now().toIso8601String());
    } catch (_) {/* best-effort */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        Center(child: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'))),
      ]);
    }
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 140),
        Icon(Icons.notifications_off_outlined, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Center(child: Text('No notifications yet', style: TextStyle(color: AppColors.textSecondary))),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _NotificationTile(item: _items[i], onTap: () => _markRead(_items[i])),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unread = item['read_at'] == null;
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final when = created != null ? DateFormat('dd MMM, hh:mm a').format(created.toLocal()) : '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: unread ? AppColors.primary.withValues(alpha: 0.3) : AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unread)
              Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6, right: 10), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']?.toString() ?? '', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(item['body']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(when, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
