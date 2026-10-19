import 'package:flutter/material.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final double padding = width < 360
            ? 14
            : width < 600
                ? 16
                : 20;

        final double fontSize = width < 360 ? 15 : 18;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xff18263F),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 7,
                backgroundColor: Colors.greenAccent,
              ),

              SizedBox(width: width < 360 ? 8 : 12),

              Expanded(
                child: Text(
                  'AI Monitoring Ready',
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right,
                color: Colors.white70,
              ),
            ],
          ),
        );
      },
    );
  }
}