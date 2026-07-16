import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Communication speed-dial.
///
/// B4 fix: this is designed to be used as a real `Scaffold.floatingActionButton`.
/// The expanding menu + dimmed scrim are rendered through the root [Overlay] and
/// anchored to the FAB with a [LayerLink], so they are never clipped by the FAB
/// slot and the FAB floats above scrolling content predictably.
class CommSpeedDial extends StatefulWidget {
  const CommSpeedDial({super.key});

  @override
  State<CommSpeedDial> createState() => _CommSpeedDialState();
}

class _CommSpeedDialState extends State<CommSpeedDial> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _open = false;

  static const _items = [
    _DialItem('Message to Parent', Icons.message_outlined),
    _DialItem('Message to Student', Icons.chat_outlined),
    _DialItem('Message to Teacher', Icons.people_outline),
    _DialItem('Suggestions', Icons.lightbulb_outline),
    _DialItem('Contact Directory', Icons.contacts_outlined),
    _DialItem('Notify Student', Icons.notifications_outlined),
    _DialItem('Notify Faculty', Icons.notifications_active_outlined),
    _DialItem('Circular', Icons.picture_as_pdf_outlined),
  ];

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    setState(() => _open = true);
  }

  void _close() {
    _removeOverlay();
    if (mounted) setState(() => _open = false);
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _onItemTap(_DialItem item) {
    _close();
    switch (item.label) {
      case 'Message to Parent':
        context.push('/notices/create', extra: {'title': 'Message to Parents', 'audience': 'parents'});
        break;
      case 'Message to Student':
        context.push('/notices/create', extra: {'title': 'Message to Students', 'audience': 'students'});
        break;
      case 'Message to Teacher':
        context.push('/notices/create', extra: {'title': 'Message to Teachers', 'audience': 'teachers'});
        break;
      case 'Notify Student':
        context.push('/notices/create', extra: {'title': 'Notify Students', 'audience': 'students'});
        break;
      case 'Notify Faculty':
        context.push('/notices/create', extra: {'title': 'Notify Faculty', 'audience': 'teachers'});
        break;
      case 'Suggestions':
        context.push('/suggestions');
        break;
      default:
        // Circular (file upload) and Contact Directory ship later.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.label} — coming in a later update'), duration: const Duration(seconds: 2)),
        );
    }
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        // Dimmed, tap-to-dismiss scrim across the whole screen.
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black.withValues(alpha: 0.3)),
          ),
        ),
        // Menu anchored to the FAB's top-right, expanding upward.
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(0, -12),
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              builder: (_, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _onItemTap(item),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 4)],
                          ),
                          child: Text(item.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 4)],
                          ),
                          child: Icon(item.icon, size: 20, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: FloatingActionButton(
        onPressed: _toggle,
        backgroundColor: AppColors.primary,
        child: AnimatedRotation(
          turns: _open ? 0.125 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.send_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _DialItem {
  final String label;
  final IconData icon;
  const _DialItem(this.label, this.icon);
}
