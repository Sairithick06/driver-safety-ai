import 'package:flutter/material.dart';

class SystemStatusCard extends StatelessWidget {
  final String aiStatus;
  final String cameraStatus;
  final String backendStatus;
  final String lastAnalysis;

  const SystemStatusCard({
    super.key,
    required this.aiStatus,
    required this.cameraStatus,
    required this.backendStatus,
    required this.lastAnalysis,
  });

  Widget _statusRow(
    IconData icon,
    Color color,
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [

          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(.15),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ),

          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xff23324A),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.20),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "System Status",
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          _statusRow(
            Icons.memory,
            Colors.green,
            "AI Engine",
            aiStatus,
          ),

          const Divider(color: Color(0xff23324A)),

          _statusRow(
            Icons.videocam,
            Colors.blue,
            "Camera",
            cameraStatus,
          ),

          const Divider(color: Color(0xff23324A)),

          _statusRow(
            Icons.cloud_done,
            Colors.orange,
            "Backend",
            backendStatus,
          ),

          const Divider(color: Color(0xff23324A)),

          _statusRow(
            Icons.schedule,
            Colors.cyan,
            "Last Analysis",
            lastAnalysis,
          ),
        ],
      ),
    );
  }
}