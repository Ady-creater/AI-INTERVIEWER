import 'dart:math';
import 'package:flutter/material.dart';

class VoiceLineWidget extends StatefulWidget {
  final bool isActive;
  final Color? color;
  final double width;
  final double height;
  const VoiceLineWidget({
    super.key,
    this.isActive = true,
    this.color,
    this.width = 60,
    this.height = 40,
  });
  @override
  State<VoiceLineWidget> createState() => _VoiceLineWidgetState();
}

class _VoiceLineWidgetState extends State<VoiceLineWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant VoiceLineWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _barHeight(int index) {
    if (!widget.isActive) return 8;

    final phase = index * 0.9;
    final value = (sin((_controller.value * 2 * pi) + phase) + 1) / 2;
    return 8 + (value * 24);
  }

  @override
  Widget build(BuildContext context) {
    final barColor = widget.color ?? Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 5,
                height: _barHeight(index),
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
