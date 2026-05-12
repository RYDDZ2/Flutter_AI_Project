import 'package:flutter/material.dart';
import '../isar_service.dart';

class ObjectListPage extends StatefulWidget {
  final int placeId;
  final String placeName;

  const ObjectListPage({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<ObjectListPage> createState() => _ObjectListPageState();
}

class _ObjectListPageState extends State<ObjectListPage> {
  final _isar = IsarService.instance;
  List<String> _objects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadObjects();
  }

  Future<void> _loadObjects() async {
    setState(() => _isLoading = true);
    final labels = await _isar.getUniqueLabelsByPlace(widget.placeId);
    setState(() {
      _objects = labels;
      _isLoading = false;
    });
  }

  Future<void> _deleteLabel(String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Remove object?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will remove "$label" from manual labels and detection history for this place.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _isar.deleteLabelFromPlace(widget.placeId, label);
      _loadObjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Objects in ${widget.placeName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadObjects,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF80CBC4)))
          : RefreshIndicator(
              onRefresh: _loadObjects,
              child: _objects.isEmpty
                  ? const Center(
                      child: Text(
                        'No objects detected or added yet.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _objects.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF242424),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.label_rounded,
                                    color: Color(0xFF80CBC4), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _objects[index],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Color(0xFFFF6B6B), size: 22),
                                onPressed: () => _deleteLabel(_objects[index]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}