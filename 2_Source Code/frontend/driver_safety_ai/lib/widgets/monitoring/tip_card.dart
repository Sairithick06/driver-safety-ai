import 'package:flutter/material.dart';

class TipCard extends StatelessWidget {
  const TipCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xff23324A),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [

              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber,
                size: 28,
              ),

              SizedBox(width: 10),

              Text(
                "Safety Tip",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          Text(
            "Stay alert and take breaks regularly during long drives.\n\n"
            "Keep both hands on the steering wheel and avoid distractions while driving.",
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}