import 'package:flutter/material.dart';

import '../core/models.dart';
import '../painters/rest_painter.dart';

class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.number,
    required this.title,
    required this.kind,
    required this.color,
    required this.onTap,
  });
  final String number;
  final String title;
  final RestKind kind;
  final Color color;
  final VoidCallback onTap;

  /// 카드 한 칸 높이. 홈 화면의 세로 배치 단위이기도 하다.
  static const double height = 116;

  /// 카드 사이 간격.
  static const double gap = 12;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CustomPaint(painter: RestPainter(kind)),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 260,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      number,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
