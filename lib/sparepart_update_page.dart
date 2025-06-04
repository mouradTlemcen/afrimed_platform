import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SparePartUpdatePage extends StatefulWidget {
  final String equipmentId;
  final String sparePartId;

  const SparePartUpdatePage({
    Key? key,
    required this.equipmentId,
    required this.sparePartId,
  }) : super(key: key);

  @override
  _SparePartUpdatePageState createState() => _SparePartUpdatePageState();
}

class _SparePartUpdatePageState extends State<SparePartUpdatePage> {
  // Predefined spare part types
  List<String> sparePartTypes = [
    'Filter',
    'Valve',
    'Hose',
    'Motor',
    'Pump'
  ];

  String? selectedType;
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSparePartData();
  }

  Future<void> _loadSparePartData() async {
    setState(() {
      isLoading = true;
    });
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(widget.equipmentId)
          .collection('spareParts')
          .doc(widget.sparePartId)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final firestoreType = data['type'] as String? ?? '';
        // If the Firestore type is not in our predefined list, add it.
        if (firestoreType.isNotEmpty && !sparePartTypes.contains(firestoreType)) {
          sparePartTypes.add(firestoreType);
        }
        setState(() {
          selectedType = firestoreType.isNotEmpty ? firestoreType : null;
          brandController.text = data['brand'] ?? '';
          modelController.text = data['model'] ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Spare part not found.")),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading spare part: $e")),
      );
    }
  }

  Future<void> _updateSparePart() async {
    if (selectedType == null || selectedType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a spare part type.")),
      );
      return;
    }

    final updatedData = {
      'type': selectedType,
      'brand': brandController.text.trim(),
      'model': modelController.text.trim(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('equipment')
          .doc(widget.equipmentId)
          .collection('spareParts')
          .doc(widget.sparePartId)
          .update(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Spare part updated successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update spare part: $e")),
      );
    }
  }

  @override
  void dispose() {
    brandController.dispose();
    modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Spare Part"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Spare Part Type Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Spare Part Type",
                border: OutlineInputBorder(),
              ),
              value: selectedType,
              items: sparePartTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedType = value;
                });
              },
            ),
            const SizedBox(height: 16),
            // Brand TextField
            TextField(
              controller: brandController,
              decoration: const InputDecoration(
                labelText: "Brand",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Model TextField
            TextField(
              controller: modelController,
              decoration: const InputDecoration(
                labelText: "Model",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _updateSparePart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0073E6),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "Update Spare Part",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}
