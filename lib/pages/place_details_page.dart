import 'package:flutter/material.dart';

import '../isar_service.dart';
import '../data/isar/schema.dart';
import 'detection_realtime_page.dart';
import 'detection_upload_page.dart';
import 'object_list_page.dart';

class PlaceDetailsPage extends StatefulWidget {
  static const routeName = '/placeDetails';

  final int placeId;

  const PlaceDetailsPage({
    super.key,
    required this.placeId,
  });

  @override
  State<PlaceDetailsPage> createState() => _PlaceDetailsPageState();
}

class _PlaceDetailsPageState extends State<PlaceDetailsPage> {
  final _isar = IsarService.instance;

  bool _isLoading = true;
  Place? _place;
  List<ManualObject> _manualObjects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final isar = await _isar.open();

    final place = await isar.places.get(widget.placeId);

    final manual = await _isar.getManualObjectsByPlace(widget.placeId);

    setState(() {
      _place = place;
      _manualObjects = manual;
      _isLoading = false;
    });
  }

  Future<void> _addOrEditManualObject({
    ManualObject? existing,
  }) async {
    final controllerLabel = TextEditingController(text: existing?.label ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                existing == null ? 'Add Object Label' : 'Edit Object Label',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Label (bebas, misal: kucing / orang / burung)',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controllerLabel,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF242424),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final label = controllerLabel.text.trim();
                        if (label.isEmpty) return;

                        // We don't write here directly; we'll do it after pop.
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80CBC4),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        existing == null ? 'Add' : 'Save',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text(
                      'Cancel / close',
                      style: TextStyle(color: Color(0xFF90CAF9)),
                    ),
                  ),
                ),
              ]
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    final label = controllerLabel.text.trim();
    if (label.isEmpty) return;

    // For edit: delete old manual row(s) by id, then add a fresh one.
    if (existing != null) {
      await _isar.deleteManualObjectById(existing.id);
    }

    await _isar.addManualObject(
      placeId: widget.placeId,
      label: label,
      count: 1, // Defaulting to 1 since we only care about existence
    );

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final placeName = _place?.name ?? 'Place';
    return Scaffold(
      appBar: AppBar(
        title: Text(placeName),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF80CBC4),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionHeader(
                    title: 'Manual Labeling',
                    icon: Icons.edit_note_rounded,
                  ),
                  const SizedBox(height: 12),
                  _manualObjects.isEmpty
                      ? const Text(
                          'Belum ada label manual.',
                          style: TextStyle(color: Colors.white70),
                        )
                      : Column(
                          children: _manualObjects
                              .map(
                                (m) => _ManualObjectTile(
                                  manual: m,
                                  onEdit: () => _addOrEditManualObject(existing: m),
                                  onDelete: () async {
                                    await _isar.deleteManualObjectById(m.id);
                                    await _load();
                                  },
                                ),
                              )
                              .toList(),
                        ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addOrEditManualObject(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Manual Object'),
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
                  const SizedBox(height: 26),
                  _buildActionButton(
                    text: 'View All Object Inventory',
                    icon: Icons.inventory_2_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ObjectListPage(
                            placeId: widget.placeId,
                            placeName: placeName,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  _buildSectionHeader(
                    title: 'Detection',
                    icon: Icons.camera_alt_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    text: 'Realtime detect & count',
                    icon: Icons.waves_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetectionRealtimePage(
                            placeId: widget.placeId,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    text: 'Upload images (multi) + detect count',
                    icon: Icons.photo_library_rounded,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetectionUploadPage(
                            placeId: widget.placeId,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF80CBC4), size: 18),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF80CBC4)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualObjectTile extends StatelessWidget {
  const _ManualObjectTile({
    required this.manual,
    required this.onEdit,
    required this.onDelete,
  });

  final ManualObject manual;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFF242424),
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: Colors.white10)),
            ),
            child: const Icon(Icons.label_rounded, color: Color(0xFF80CBC4), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manual.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white70),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
