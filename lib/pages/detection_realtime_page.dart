import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../isar_service.dart';
import '../data/isar/schema.dart';

class DetectionRealtimePage extends StatefulWidget {
  static const routeName = '/realtimeDetect';

  final int placeId;

  const DetectionRealtimePage({
    super.key,
    required this.placeId,
  });

  @override
  State<DetectionRealtimePage> createState() => _DetectionRealtimePageState();
}

class _DetectionRealtimePageState extends State<DetectionRealtimePage> {
  final _isar = IsarService.instance;

  List<YOLOResult> _results = const [];
  double _fps = 0;

  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;
  bool _showOverlays = true;
  LensFacing _lensFacing = LensFacing.back;

  bool _isSavingSnapshot = false;

  int _currentTotalCount() => _results.length;

  Map<String, int> _countPerLabel(List<YOLOResult> results) {
    final counts = <String, int>{};
    for (final r in results) {
      final label = r.className.trim();
      if (label.isEmpty) continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _saveSnapshot() async {
    if (_isSavingSnapshot) return;
    setState(() => _isSavingSnapshot = true);

    final isar = await _isar.open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final total = _currentTotalCount();
    final labelCounts = _countPerLabel(_results);
    final countsJson = _toCountsJson(labelCounts);

    await isar.writeTxn(() async {
      final snapshot = DetectionSnapshot()
        ..placeId = widget.placeId
        ..sourceType = 'realtime'
        ..timestampMs = now
        ..totalCount = total
        ..countsJson = countsJson;

      final snapshotId = await isar.detectionSnapshots.put(snapshot);

      for (final entry in labelCounts.entries) {
        final row = DetectionLabelCount()
          ..snapshotId = snapshotId
          ..label = entry.key
          ..count = entry.value;
        await isar.detectionLabelCounts.put(row);
      }
    });

    if (mounted) {
      setState(() => _isSavingSnapshot = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Snapshot saved to local DB')),
      );
    }
  }

  String _toCountsJson(Map<String, int> labelCounts) {
    // Manual JSON stringification (Isar schema stores String)
    final sortedKeys = labelCounts.keys.toList()..sort();
    final pairs = sortedKeys
        .map((k) => '"${k.replaceAll('"', '\\"')}":${labelCounts[k]}')
        .join(',');
    return '{$pairs}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_front_rounded),
            onPressed: () {
              setState(() {
                _lensFacing = _lensFacing == LensFacing.back
                    ? LensFacing.front
                    : LensFacing.back;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white10, width: 1),
                ),
                child: YOLOView(
                  key: ValueKey('realtime-$_lensFacing-$_showOverlays'),
                  modelPath: 'assets/models/yolo11n_int8.tflite',
                  confidenceThreshold: _confidenceThreshold,
                  iouThreshold: _iouThreshold,
                  lensFacing: _lensFacing,
                  showOverlays: _showOverlays,
                  onResult: (results) {
                    setState(() => _results = results);
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
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final total = _currentTotalCount();
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _metric(
                label: 'DETECTIONS',
                value: total.toString(),
                icon: Icons.api_rounded,
                color: const Color(0xFF80CBC4),
              ),
              const SizedBox(width: 16),
              _metric(
                label: 'FPS',
                value: _fps.toStringAsFixed(1),
                icon: Icons.speed_rounded,
                color: const Color(0xFF90CAF9),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSnapshot,
              icon: _isSavingSnapshot
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSavingSnapshot ? 'Saving...' : 'Save snapshot now',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF80CBC4),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.withOpacity(0.8)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
