import 'package:flutter/material.dart';

/// Wraps any child with a subtle "press" micro-interaction: the child scales
/// down slightly and dims while the finger is down, then springs back.
///
/// This is the single source of tactility across the app — cards, buttons, and
/// list rows all route their taps through it so every pressable surface feels
/// the same, the way it does in Linear or Things.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius,
    this.enableFeedback = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far the child shrinks while pressed (1.0 = no shrink).
  final double scale;

  /// Clips the ripple/child to this radius when provided.
  final BorderRadius? borderRadius;
  final bool enableFeedback;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down && enabled ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.borderRadius != null
              ? ClipRRect(
                  borderRadius: widget.borderRadius!,
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}
