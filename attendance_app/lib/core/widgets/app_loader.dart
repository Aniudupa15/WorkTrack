import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Standard brand-colored loading spinner, centered.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.size = 28, this.strokeWidth = 3});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: context.colors.brand,
        ),
      ),
    );
  }
}
