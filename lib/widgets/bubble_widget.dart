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
    final bubbleColor = isHighlighted ? Colors.orange : color;

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubbleColor,
          border: isHighlighted
              ? Border.all(
                  color: Colors.orange.shade100,
                  width: 2.5,
                )
              : null,
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: Colors.orange.withAlpha(120),
                    spreadRadius: 1,
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Center(
            child: label != null
                ? Text(
                    label!,
                    style: TextStyle(
                      color: isHighlighted ? Colors.black87 : Colors.white,
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
