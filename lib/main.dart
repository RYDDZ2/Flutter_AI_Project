import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'pages/home_page.dart';
import 'pages/place_details_page.dart';
import 'pages/detection_realtime_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF80CBC4),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// NOTE: Keep this widget only if you still need it during development.
/// The app entrypoint is now [HomePage] (see MaterialApp.home above).
class LegacyYOLODetection extends StatefulWidget {
  const LegacyYOLODetection({super.key});

  @override
  State<LegacyYOLODetection> createState() => _LegacyYOLODetectionState();
}

class _LegacyYOLODetectionState extends State<LegacyYOLODetection> {
  List<YOLOResult> _detections = [];
  double _fps = 0;

  // Settings variables
  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;
  bool _showOverlays = true;
  LensFacing _lensFacing = LensFacing.back;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VISION AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            onPressed: () => _showSettings(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: YOLOView(
                  key: ValueKey('$_lensFacing-$_showOverlays'),
                  modelPath: 'assets/models/yolo11n_int8.tflite',
                  confidenceThreshold: _confidenceThreshold,
                  iouThreshold: _iouThreshold,
                  lensFacing: _lensFacing,
                  showOverlays: _showOverlays,
                  onResult: (results) {
                    setState(() => _detections = results);
                  },
                  onPerformanceMetrics: (metrics) {
                    setState(() => _fps = metrics.fps);
                  },
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildInfoPanel(),
          ),
          Positioned(
            right: 32,
            bottom: 120,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _lensFacing = _lensFacing == LensFacing.back
                      ? LensFacing.front
                      : LensFacing.back;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF242424).withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: const Icon(
                  Icons.flip_camera_ios_rounded,
                  color: Color(0xFF80CBC4),
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'DETECTION SETTINGS',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingSlider(
                    label: 'Confidence Threshold',
                    value: _confidenceThreshold,
                    onChanged: (val) {
                      setModalState(() => _confidenceThreshold = val);
                      setState(() {});
                    },
                  ),
                  _buildSettingSlider(
                    label: 'IOU Threshold',
                    value: _iouThreshold,
                    onChanged: (val) {
                      setModalState(() => _iouThreshold = val);
                      setState(() {});
                    },
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  SwitchListTile(
                    title: const Text(
                      'Show Visual Overlays',
                      style: TextStyle(color: Colors.white70),
                    ),
                    value: _showOverlays,
                    activeColor: const Color(0xFF80CBC4),
                    onChanged: (val) {
                      setModalState(() => _showOverlays = val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingSlider({
    required String label,
    required double value,
    required Function(double) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(
              value.toStringAsFixed(2),
              style: const TextStyle(color: Color(0xFF80CBC4)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.1,
          max: 0.9,
          activeColor: const Color(0xFF80CBC4),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetricItem(
            label: 'DETECTIONS',
            value: _detections.length.toString(),
            icon: Icons.api_rounded,
            color: const Color(0xFF80CBC4),
          ),
          Container(width: 1, height: 40, color: Colors.white10),
          _buildMetricItem(
            label: 'PERFORMANCE',
            value: '${_fps.toStringAsFixed(1)} FPS',
            icon: Icons.speed_rounded,
            color: const Color(0xFF90CAF9),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
