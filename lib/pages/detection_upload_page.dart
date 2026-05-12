import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../isar_service.dart';
import '../data/isar/schema.dart';

class DetectionUploadPage extends StatefulWidget {
  final int placeId;

  const DetectionUploadPage({
    super.key,
    required this.placeId,
  });

  @override
  State<DetectionUploadPage> createState() => _DetectionUploadPageState();
}

class _DetectionUploadPageState extends State<DetectionUploadPage> {
  final _isar = IsarService.instance;
  final _picker = ImagePicker();

  final List<Uint8List> _selectedImages = [];
  bool _isRunning = false;

  double _confidenceThreshold = 0.5;
  double _iouThreshold = 0.45;

  // Store labels found per image
  List<List<String>> _perImageLabels = [];

  Future<void> _pickMultiImages() async {
    final result = await _picker.pickMultiImage(
      imageQuality: 100,
    );

    if (result == null || result.isEmpty) return;

    final images = <Uint8List>[];
    for (final xfile in result) {
      final bytes = await xfile.readAsBytes();
      images.add(bytes);
    }

    setState(() {
      _selectedImages
        ..clear()
        ..addAll(images);
      _perImageLabels = List<List<String>>.filled(images.length, []);
    });
  }

  Map<String, int> _countPerLabel(List<YOLOResult> results) {
    final counts = <String, int>{};
    for (final r in results) {
      final label = r.className.trim();
      if (label.isEmpty) continue;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }

  String _toCountsJson(Map<String, int> labelCounts) {
    final sortedKeys = labelCounts.keys.toList()..sort();
    final pairs = sortedKeys
        .map((k) => '"${k.replaceAll('"', '\\"')}":${labelCounts[k]}')
        .join(',');
    return '{$pairs}';
  }

  Future<void> _runDetectAndSave() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isRunning = true;
    });

    try {
      // Load YOLO model once for all images
      final yolo = YOLO(modelPath: 'assets/models/yolo11n_int8.tflite');

      await yolo.loadModel();

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final perImageResults = <List<String>>[];
      final labelCountsJsons = <String>[];

      for (var i = 0; i < _selectedImages.length; i++) {
        final imageBytes = _selectedImages[i];

        final output = await yolo.predict(
          imageBytes,
          confidenceThreshold: _confidenceThreshold,
          iouThreshold: _iouThreshold,
        );

        final detectionsRaw = output['detections'] as List<dynamic>;
        final detections = detectionsRaw
            .map((d) => YOLOResult.fromMap(d as Map<String, dynamic>))
            .toList();

        final total = detections.length;
        final labels = detections.map((e) => e.className).toSet().toList();
        perImageResults.add(labels);

        final labelCounts = _countPerLabel(detections);
        final countsJson = _toCountsJson(labelCounts);
        labelCountsJsons.add(countsJson);

        // Save snapshot per image with its own timestamp
        final snapshot = DetectionSnapshot()
          ..placeId = widget.placeId
          ..sourceType = 'upload'
          ..timestampMs = nowMs + i // keep ordering deterministic within one run
          ..totalCount = total
          ..countsJson = countsJson;

        final isar = await _isar.open();
        await isar.writeTxn(() async {
          final snapshotId = await isar.detectionSnapshots.put(snapshot);

          for (final entry in labelCounts.entries) {
            final row = DetectionLabelCount()
              ..snapshotId = snapshotId
              ..label = entry.key
              ..count = entry.value;

            await isar.detectionLabelCounts.put(row);
          }
        });
      }

      setState(() {
        _perImageLabels = perImageResults;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload + detection selesai. Snapshot tersimpan.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload & Detect'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? null : _pickMultiImages,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Pick multiple images'),
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
            const SizedBox(height: 16),

            // Selected images summary
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selected: ${_selectedImages.length}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _selectedImages.isEmpty
                  ? const Center(
                      child: Text(
                        'Pilih beberapa gambar dulu.\nNanti akan dihitung objeknya dan disimpan timestamp per gambar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _selectedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final labels = _perImageLabels.isNotEmpty
                            ? _perImageLabels[index]
                            : <String>[];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF242424),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.image_rounded,
                                    color: Color(0xFF80CBC4)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Image #${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Objects: ${labels.isEmpty ? "None" : labels.join(", ")}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 14),

            // Quick run button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _runDetectAndSave,
                icon: _isRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_isRunning ? 'Running...' : 'Detect & Save Snapshots'),
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
