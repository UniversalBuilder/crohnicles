import 'package:flutter/material.dart';

/// Custom painter for abdomen silhouette with 9 anatomical zones (3x3 grid)
/// Used in symptom entry dialog to help users locate pain visually
class AbdomenSilhouettePainter extends CustomPainter {
  final Set<int> selectedZones;
  final Color selectedColor;
  final Color strokeColor;

  AbdomenSilhouettePainter({
    required this.selectedZones,
    this.selectedColor = Colors.blue,
    this.strokeColor = Colors.grey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = strokeColor.withValues(alpha: 0.3);

    final bodyFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = strokeColor.withValues(alpha: 0.05);

    final selectedFillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = selectedColor.withValues(alpha: 0.2);

    final selectedBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = selectedColor;

    // Draw body silhouette (torso + abdomen)
    final bodyPath = Path();

    // Shoulders (curved top)
    bodyPath.moveTo(size.width * 0.2, size.height * 0.05);
    bodyPath.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.0,
      size.width * 0.8,
      size.height * 0.05,
    );

    // Right side (slight curve)
    bodyPath.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.5,
      size.width * 0.75,
      size.height * 0.95,
    );

    // Bottom (pelvis)
    bodyPath.lineTo(size.width * 0.25, size.height * 0.95);

    // Left side (slight curve)
    bodyPath.quadraticBezierTo(
      size.width * 0.18,
      size.height * 0.5,
      size.width * 0.2,
      size.height * 0.05,
    );

    bodyPath.close();

    // Fill body outline
    canvas.drawPath(bodyPath, bodyFillPaint);
    canvas.drawPath(bodyPath, outlinePaint);

    // Draw 3x3 grid for anatomical zones
    final gridWidth = size.width * 0.5;
    final gridHeight = size.height * 0.75;
    final cellWidth = gridWidth / 3;
    final cellHeight = gridHeight / 3;
    final startX = size.width * 0.25;
    final startY = size.height * 0.1;

    // Draw grid lines
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = strokeColor.withValues(alpha: 0.4);

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(startX + i * cellWidth, startY),
        Offset(startX + i * cellWidth, startY + gridHeight),
        gridPaint,
      );
    }

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(startX, startY + i * cellHeight),
        Offset(startX + gridWidth, startY + i * cellHeight),
        gridPaint,
      );
    }

    // Fill selected zones
    for (int zoneIndex in selectedZones) {
      if (zoneIndex < 0 || zoneIndex >= 9) continue;

      final row = zoneIndex ~/ 3;
      final col = zoneIndex % 3;

      final rect = Rect.fromLTWH(
        startX + col * cellWidth,
        startY + row * cellHeight,
        cellWidth,
        cellHeight,
      );

      // Fill
      canvas.drawRect(rect, selectedFillPaint);
      // Border
      canvas.drawRect(rect, selectedBorderPaint);
    }

    // Draw outer grid border
    final gridBorderRect = Rect.fromLTWH(startX, startY, gridWidth, gridHeight);
    canvas.drawRect(gridBorderRect, outlinePaint);
  }

  @override
  bool shouldRepaint(AbdomenSilhouettePainter oldDelegate) {
    return oldDelegate.selectedZones != selectedZones ||
        oldDelegate.selectedColor != selectedColor ||
        oldDelegate.strokeColor != strokeColor;
  }
}
