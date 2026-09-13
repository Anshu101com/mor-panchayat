import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBubbleBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBubbleBackground({super.key, required this.child});

  @override
  State<AnimatedBubbleBackground> createState() =>
      _AnimatedBubbleBackgroundState();
}

class _AnimatedBubbleBackgroundState extends State<AnimatedBubbleBackground> {
  final Random _random = Random();

  late final List<_BubbleData> _bubbles;

  @override
  void initState() {
    super.initState();

    _bubbles = List.generate(16, (_) => _BubbleData.random(_random));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ============================================================
        // BACKGROUND
        // ============================================================
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FBF9), Color(0xFFF2F8F5), Color(0xFFF8FAF9)],
            ),
          ),
        ),

        // ============================================================
        // BUBBLES
        // IMPORTANT: bubbles cannot receive touches
        // ============================================================
        IgnorePointer(
          ignoring: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ..._bubbles.map((bubble) => _AnimatedBubble(data: bubble)),
            ],
          ),
        ),

        // ============================================================
        // PAGE
        // ============================================================
        widget.child,
      ],
    );
  }
}

// ==================================================================
// BUBBLE DATA
// ==================================================================

class _BubbleData {
  final double size;
  final double left;
  final double top;
  final Color color;
  final double opacity;
  final int duration;
  final double moveX;
  final double moveY;
  final double blur;

  const _BubbleData({
    required this.size,
    required this.left,
    required this.top,
    required this.color,
    required this.opacity,
    required this.duration,
    required this.moveX,
    required this.moveY,
    required this.blur,
  });

  factory _BubbleData.random(Random random) {
    const colors = [
      Color(0xFF176B4D),
      Color(0xFF2E8B68),
      Color(0xFF4CAF88),
      Color(0xFF67B7A0),
      Color(0xFFF2B84B),
      Color(0xFFF59E55),
      Color(0xFF4A90E2),
      Color(0xFF7C83FD),
      Color(0xFF9B72CF),
      Color(0xFFE879A9),
    ];

    return _BubbleData(
      size: 60 + random.nextDouble() * 180,
      left: -100 + random.nextDouble() * 500,
      top: -100 + random.nextDouble() * 900,
      color: colors[random.nextInt(colors.length)],
      opacity: 0.07 + random.nextDouble() * 0.09,
      duration: 3500 + random.nextInt(4500),
      moveX: -45 + random.nextDouble() * 90,
      moveY: -55 + random.nextDouble() * 110,
      blur: 20 + random.nextDouble() * 25,
    );
  }
}

// ==================================================================
// ANIMATED BUBBLE
// ==================================================================

class _AnimatedBubble extends StatefulWidget {
  final _BubbleData data;

  const _AnimatedBubble({required this.data});

  @override
  State<_AnimatedBubble> createState() => _AnimatedBubbleState();
}

class _AnimatedBubbleState extends State<_AnimatedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _xAnimation;
  late final Animation<double> _yAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.data.duration),
    );

    final animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    _xAnimation = Tween<double>(
      begin: 0,
      end: widget.data.moveX,
    ).animate(animation);

    _yAnimation = Tween<double>(
      begin: 0,
      end: widget.data.moveY,
    ).animate(animation);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(animation);

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: widget.data.left + _xAnimation.value,
          top: widget.data.top + _yAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: _Bubble(data: widget.data),
          ),
        );
      },
    );
  }
}

// ==================================================================
// BUBBLE
// ==================================================================

class _Bubble extends StatelessWidget {
  final _BubbleData data;

  const _Bubble({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: data.size,
      height: data.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: [
            data.color.withOpacity(data.opacity),
            data.color.withOpacity(data.opacity * 0.55),
            data.color.withOpacity(0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(data.opacity * 0.7),
            blurRadius: data.blur,
            spreadRadius: 5,
          ),
        ],
      ),
    );
  }
}
