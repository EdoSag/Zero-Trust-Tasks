import 'package:flutter/material.dart';

/// A placeholder card with a gentle pulsing animation, shown while tasks
/// are loading (item 13).
class SkeletonTaskCard extends StatefulWidget {
  const SkeletonTaskCard({super.key});

  @override
  State<SkeletonTaskCard> createState() => _SkeletonTaskCardState();
}

class _SkeletonTaskCardState extends State<SkeletonTaskCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.4, end: 1.0)),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12.0),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _block(baseColor, width: 24, height: 24, isCircle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _block(baseColor, width: 160, height: 16),
                        const SizedBox(height: 8),
                        _block(baseColor, width: 100, height: 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _block(baseColor, width: 70, height: 20),
                  const SizedBox(width: 8),
                  _block(baseColor, width: 70, height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(
    Color color, {
    required double width,
    required double height,
    bool isCircle = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(4),
      ),
    );
  }
}
