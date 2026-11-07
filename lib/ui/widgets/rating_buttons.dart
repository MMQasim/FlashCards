/// The four answer buttons, with the interval each one would schedule.
library;

import 'package:flutter/material.dart';

import '../../srs/sm2.dart';
import '../theme.dart';

class RatingButtons extends StatelessWidget {
  const RatingButtons({
    required this.onRate,
    required this.intervals,
    this.showIntervals = true,
    super.key,
  });

  final ValueChanged<Rating> onRate;
  final Map<Rating, Duration> intervals;
  final bool showIntervals;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      children: [
        for (final rating in Rating.values) ...[
          if (rating != Rating.again) const SizedBox(width: 8),
          Expanded(
            child: _RatingButton(
              rating: rating,
              color: AppTheme.ratingColor(rating, brightness),
              interval: showIntervals ? intervals[rating] : null,
              onPressed: () => onRate(rating),
            ),
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.rating,
    required this.color,
    required this.onPressed,
    this.interval,
  });

  final Rating rating;
  final Color color;
  final Duration? interval;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppTheme.ratingLabel(rating);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        minimumSize: const Size.fromHeight(58),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (interval != null)
            Text(
              formatInterval(interval!),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}

/// Single full-width button used before the answer is revealed.
class RevealButton extends StatelessWidget {
  const RevealButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.visibility_outlined, size: 20),
      label: const Text('Show answer'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58)),
    );
  }
}
