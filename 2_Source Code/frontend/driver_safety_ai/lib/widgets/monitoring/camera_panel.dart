import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPanel extends StatelessWidget {
  final bool isReady;
  final CameraController controller;

  const CameraPanel({
    super.key,
    required this.isReady,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff23324A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [

            /// CAMERA
            /// CAMERA
            Positioned.fill(
              child: isReady
              ? LayoutBuilder(
                builder: (context, constraints) {
                  return FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: CameraPreview(controller),
                      ),
                    );
                  },
                )
              : const Center(
                child: CircularProgressIndicator(),
                ),
            ),
            /// LIVE BADGE
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.65),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: Color(0xff4ADE80),
                    ),
                    SizedBox(width: 8),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// FACE GUIDE
            Center(
              child: IgnorePointer(
                child: Container(
                  width: 280,
                  height: 330,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xff4ADE80),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),

            /// TOP LEFT
            Positioned(
              top: 42,
              left: 42,
              child: _corner(),
            ),

            /// TOP RIGHT
            Positioned(
              top: 42,
              right: 42,
              child: Transform.rotate(
                angle: 1.57,
                child: _corner(),
              ),
            ),

            /// BOTTOM LEFT
            Positioned(
              bottom: 42,
              left: 42,
              child: Transform.rotate(
                angle: -1.57,
                child: _corner(),
              ),
            ),

            /// BOTTOM RIGHT
            Positioned(
              bottom: 42,
              right: 42,
              child: Transform.rotate(
                angle: 3.14,
                child: _corner(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner() {
    return SizedBox(
      width: 42,
      height: 42,
      child: CustomPaint(
        painter: _CornerPainter(),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xff4ADE80)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();

    path.moveTo(size.width, 0);
    path.lineTo(0, 0);
    path.lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}