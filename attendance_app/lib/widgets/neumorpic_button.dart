// lib/widgets/punch_button.dart

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PunchButton — Neumorphic button widget for the PunchIn app
//
// Usage examples:
//
//   PunchButton(label: 'Sign In', onTap: _login)
//   PunchButton.gold(label: 'Punch In', onTap: _punchIn)
//   PunchButton.dark(label: 'Sign In', onTap: _login)
//   PunchButton.icon(icon: Icons.search, onTap: () {})
//   PunchButton(label: 'Disabled', onTap: null)
//   PunchButton.gold(label: 'Loading…', isLoading: true, onTap: _login)
// ─────────────────────────────────────────────────────────────────────────────

enum PunchButtonVariant { cream, gold, dark }
enum PunchButtonSize    { small, medium, large, full }

class PunchButton extends StatefulWidget {
  final String?           label;
  final IconData?         prefixIcon;
  final IconData?         suffixIcon;
  final Widget?           customChild;
  final VoidCallback?     onTap;
  final PunchButtonVariant variant;
  final PunchButtonSize    size;
  final bool              isPill;
  final bool              isLoading;
  final Widget?           badge;

  const PunchButton({
    super.key,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.customChild,
    required this.onTap,
    this.variant  = PunchButtonVariant.cream,
    this.size     = PunchButtonSize.medium,
    this.isPill   = false,
    this.isLoading= false,
    this.badge,
  });

  // ── Named constructors ─────────────────────────────────────────────────────
  const PunchButton.gold({
    super.key,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.customChild,
    required this.onTap,
    this.size     = PunchButtonSize.medium,
    this.isPill   = false,
    this.isLoading= false,
    this.badge,
  }) : variant = PunchButtonVariant.gold;

  const PunchButton.dark({
    super.key,
    this.label,
    this.prefixIcon,
    this.suffixIcon,
    this.customChild,
    required this.onTap,
    this.size     = PunchButtonSize.medium,
    this.isPill   = false,
    this.isLoading= false,
    this.badge,
  }) : variant = PunchButtonVariant.dark;

  // ── Icon-only button ───────────────────────────────────────────────────────
  static Widget icon({
    Key? key,
    required IconData icon,
    required VoidCallback? onTap,
    PunchButtonVariant variant = PunchButtonVariant.cream,
    double size = 52,
    Color? iconColor,
  }) {
    return _PunchIconButton(
      key: key,
      icon: icon,
      onTap: onTap,
      variant: variant,
      buttonSize: size,
      iconColor: iconColor,
    );
  }

  @override
  State<PunchButton> createState() => _PunchButtonState();
}

class _PunchButtonState extends State<PunchButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  // ── Tokens ─────────────────────────────────────────────────────────────────
  static const Color _cream      = Color(0xFFF7F2E9);
  static const Color _creamLight = Color(0xFFFFFFFF);
  static const Color _creamShadow= Color(0xFFC8B89A);

  static const Color _gold       = Color(0xFF8B6520);
  static const Color _goldMid    = Color(0xFFB87A28);

  static const Color _dark       = Color(0xFF1C1410);
  static const Color _darkLight  = Color(0xFF2E2318);
  static const Color _darkShadow = Color(0xFF0A0704);

  static const Color _textDark   = Color(0xFF1C1410);
  static const Color _textMuted  = Color(0xFF9C8E7A);

  // ── Raised shadow ──────────────────────────────────────────────────────────
  List<BoxShadow> _raisedShadow() {
    switch (widget.variant) {
      case PunchButtonVariant.cream:
        return [
          BoxShadow(color: _creamShadow, blurRadius: 12, offset: const Offset(5, 5)),
          BoxShadow(color: _creamLight,  blurRadius: 12, offset: const Offset(-5, -5)),
        ];
      case PunchButtonVariant.gold:
        return [
          BoxShadow(color: const Color(0xFF5A3200).withOpacity(0.48), blurRadius: 14, offset: const Offset(5, 5)),
          BoxShadow(color: const Color(0xFFDCB464).withOpacity(0.32), blurRadius: 14, offset: const Offset(-5, -5)),
        ];
      case PunchButtonVariant.dark:
        return [
          BoxShadow(color: _darkShadow, blurRadius: 12, offset: const Offset(5, 5)),
          BoxShadow(color: _darkLight,  blurRadius: 12, offset: const Offset(-5, -5)),
        ];
    }
  }

  // ── Pressed / inset shadow ─────────────────────────────────────────────────
  List<BoxShadow> _insetShadow() {
    switch (widget.variant) {
      case PunchButtonVariant.cream:
        return [
          BoxShadow(color: _creamShadow, blurRadius: 10, offset: const Offset(4, 4),  spreadRadius: 0),
          BoxShadow(color: _creamLight,  blurRadius: 10, offset: const Offset(-4, -4), spreadRadius: 0),
        ];
      case PunchButtonVariant.gold:
        return [
          BoxShadow(color: const Color(0xFF3C1E00).withOpacity(0.5), blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: const Color(0xFFD2A046).withOpacity(0.28), blurRadius: 10, offset: const Offset(-4, -4)),
        ];
      case PunchButtonVariant.dark:
        return [
          BoxShadow(color: _darkShadow, blurRadius: 10, offset: const Offset(4, 4)),
          BoxShadow(color: _darkLight,  blurRadius: 10, offset: const Offset(-4, -4)),
        ];
    }
  }

  Color get _bgColor {
    switch (widget.variant) {
      case PunchButtonVariant.cream: return _cream;
      case PunchButtonVariant.gold:  return _goldMid;
      case PunchButtonVariant.dark:  return _dark;
    }
  }

  Color get _fgColor {
    switch (widget.variant) {
      case PunchButtonVariant.cream: return _textDark;
      case PunchButtonVariant.gold:  return Colors.white;
      case PunchButtonVariant.dark:  return Colors.white;
    }
  }

  Color get _mutedFg {
    switch (widget.variant) {
      case PunchButtonVariant.cream: return _textMuted;
      case PunchButtonVariant.gold:  return Colors.white.withOpacity(0.6);
      case PunchButtonVariant.dark:  return Colors.white.withOpacity(0.4);
    }
  }

  // ── Size tokens ─────────────────────────────────────────────────────────────
  double get _height {
    switch (widget.size) {
      case PunchButtonSize.small:  return 38;
      case PunchButtonSize.medium: return 48;
      case PunchButtonSize.large:  return 56;
      case PunchButtonSize.full:   return 52;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case PunchButtonSize.small:  return const EdgeInsets.symmetric(horizontal: 18);
      case PunchButtonSize.medium: return const EdgeInsets.symmetric(horizontal: 24);
      case PunchButtonSize.large:  return const EdgeInsets.symmetric(horizontal: 32);
      case PunchButtonSize.full:   return const EdgeInsets.symmetric(horizontal: 24);
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case PunchButtonSize.small:  return 12.5;
      case PunchButtonSize.medium: return 14;
      case PunchButtonSize.large:  return 15.5;
      case PunchButtonSize.full:   return 15;
    }
  }

  double get _borderRadius {
    if (widget.isPill) return 50;
    switch (widget.size) {
      case PunchButtonSize.small:  return 10;
      case PunchButtonSize.medium: return 14;
      case PunchButtonSize.large:  return 16;
      case PunchButtonSize.full:   return 14;
    }
  }

  bool get _disabled => widget.onTap == null && !widget.isLoading;

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isFullWidth = widget.size == PunchButtonSize.full;

    return GestureDetector(
      onTapDown:   _disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp:     _disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: _disabled ? null : ()  => setState(() => _pressed = false),
      onTap:       _disabled || widget.isLoading ? null : widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        width: isFullWidth ? double.infinity : null,
        height: _height,
        padding: _padding,
        decoration: BoxDecoration(
          color: _disabled ? _cream.withOpacity(0.6) : _bgColor,
          borderRadius: BorderRadius.circular(_borderRadius),
          boxShadow: _disabled
              ? []
              : (_pressed ? _insetShadow() : _raisedShadow()),
        ),
        transform: _pressed && !_disabled
            ? (Matrix4.identity()..scale(0.984))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: _buildChild(),
      ),
    );
  }

  Widget _buildChild() {
    if (widget.customChild != null) return widget.customChild!;

    if (widget.isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: _fgColor,
              strokeWidth: 2,
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(width: 10),
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: _fontSize,
                fontWeight: FontWeight.w700,
                color: _mutedFg,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.prefixIcon != null) ...[
          Icon(widget.prefixIcon, color: _fgColor, size: _fontSize + 2),
          const SizedBox(width: 8),
        ],
        if (widget.label != null)
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: _fontSize,
              fontWeight: FontWeight.w700,
              color: _disabled ? _textMuted : _fgColor,
              letterSpacing: 0.3,
            ),
          ),
        if (widget.suffixIcon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.suffixIcon, color: _fgColor, size: _fontSize + 2),
        ],
        if (widget.badge != null) ...[
          const SizedBox(width: 8),
          widget.badge!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PunchIconButton — square icon-only neumorphic button
// ─────────────────────────────────────────────────────────────────────────────
class _PunchIconButton extends StatefulWidget {
  final IconData           icon;
  final VoidCallback?      onTap;
  final PunchButtonVariant variant;
  final double             buttonSize;
  final Color?             iconColor;

  const _PunchIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.variant,
    required this.buttonSize,
    this.iconColor,
  });

  @override
  State<_PunchIconButton> createState() => _PunchIconButtonState();
}

class _PunchIconButtonState extends State<_PunchIconButton> {
  bool _pressed = false;

  static const Color _cream       = Color(0xFFF7F2E9);
  static const Color _creamLight  = Color(0xFFFFFFFF);
  static const Color _creamShadow = Color(0xFFC8B89A);
  static const Color _dark        = Color(0xFF1C1410);
  static const Color _darkLight   = Color(0xFF2E2318);
  static const Color _darkShadow  = Color(0xFF0A0704);
  static const Color _goldMid     = Color(0xFFB87A28);
  static const Color _textMid     = Color(0xFF4A3F32);

  Color get _bg => widget.variant == PunchButtonVariant.dark ? _dark : _cream;

  List<BoxShadow> get _raised => widget.variant == PunchButtonVariant.dark
      ? [
    BoxShadow(color: _darkShadow, blurRadius: 12, offset: const Offset(5, 5)),
    BoxShadow(color: _darkLight,  blurRadius: 12, offset: const Offset(-5, -5)),
  ]
      : [
    BoxShadow(color: _creamShadow, blurRadius: 12, offset: const Offset(5, 5)),
    BoxShadow(color: _creamLight,  blurRadius: 12, offset: const Offset(-5, -5)),
  ];

  List<BoxShadow> get _inset => widget.variant == PunchButtonVariant.dark
      ? [
    BoxShadow(color: _darkShadow, blurRadius: 9, offset: const Offset(3, 3)),
    BoxShadow(color: _darkLight,  blurRadius: 9, offset: const Offset(-3, -3)),
  ]
      : [
    BoxShadow(color: _creamShadow, blurRadius: 9, offset: const Offset(3, 3)),
    BoxShadow(color: _creamLight,  blurRadius: 9, offset: const Offset(-3, -3)),
  ];

  Color get _iconColor {
    if (widget.iconColor != null) return widget.iconColor!;
    return widget.variant == PunchButtonVariant.dark
        ? Colors.white.withOpacity(0.75)
        : _textMid;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        width:  widget.buttonSize,
        height: widget.buttonSize,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(widget.buttonSize * 0.30),
          boxShadow: _pressed ? _inset : _raised,
        ),
        transform: _pressed
            ? (Matrix4.identity()..scale(0.96))
            : Matrix4.identity(),
        transformAlignment: Alignment.center,
        child: Icon(widget.icon, color: _iconColor, size: widget.buttonSize * 0.38),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PunchBadge — small label chip used inside PunchButton.badge
// ─────────────────────────────────────────────────────────────────────────────
class PunchBadge extends StatelessWidget {
  final String text;

  const PunchBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0C060),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1C1410),
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PunchInsetContainer — neumorphic inset box (for read-only fields, cards)
// ─────────────────────────────────────────────────────────────────────────────
class PunchInsetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;

  const PunchInsetContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2E9),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(color: Color(0xFFC8B89A), blurRadius: 10, offset: Offset(4, 4)),
          BoxShadow(color: Color(0xFFFFFFFF), blurRadius: 10, offset: Offset(-4, -4)),
        ],
      ),
      child: child,
    );
  }
}