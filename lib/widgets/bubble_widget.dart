import 'package:flutter/material.dart';

class BubbleWidget extends StatelessWidget {
  final Color color;
  final bool isHighlighted;
  final VoidCallback onTap;
  final String? label;

  const BubbleWidget({
    super.key,
    required this.color,
    this.isHighlighted = false,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: isHighlighted
              ? Border.all(
                  color: Colors.white,
                  width: 3.0,
                )
              : null,
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: Colors.white.withAlpha(128),
                    spreadRadius: 2,
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50), // For ripple effect
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}