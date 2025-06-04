import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class EditAcquiredEquipmentPage extends StatefulWidget {
  final String docId;                  // Firestore doc ID
  final Map<String, dynamic> docData;  // Current doc fields

  const EditAcquiredEquipmentPage({
    Key? key,
    required this.docId,
    required this.docData,
  }) : super(key: key);

  @override
  _EditAcquiredEquipmentPageState createState() =>
      _EditAcquiredEquipmentPageState();
}

class _EditAcquiredEquipmentPageState extends State<EditAcquiredEquipmentPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Same fixed list of equipment types
  final List<String> fixedTypes = const [
    'Room',
    'Container',
    'Skid',
    'Electrical Panel',
    'Compressor',
    'Air Tank',
    'Dryer',
    'Pneumatic System',
    'Oxygen Generator',
    'Oxygen Tank',
    'Booster',
    'Vacume pump',
    'ATS',
    'Genset',
    'AVR',
    'Filling Ramp',
    'Backup Ramp',
    'MGPS',
  ];

  // Fetched definitions for brand/model
  List<Map<String, dynamic>> definitions = [];

  // Selected fields (for dropdowns)
  String? selectedType;
  String? selectedBrand;
  String? selectedModel;

  // Text controllers for the rest
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _deliveryNoteNumberController =
  TextEditingController();

  // New fields
  final TextEditingController _linkedStatusController = TextEditingController();
  final TextEditingController _installationDateController =
  TextEditingController();
  final TextEditingController _commissioningDateController =
  TextEditingController();
  final TextEditingController _functionalStatusController =
  TextEditingController();

  // Storing file URLs if changed
  String? invoiceUrl;
  String? deliveryNoteUrl;

  @override
  void initState() {
    super.initState();
    // 1) Load definitions for brand/model
    _fetchEquipmentDefinitions();

    // 2) Initialize form fields from widget.docData
    final data = widget.docData;

    selectedType = data['equipmentType'] as String?;   // e.g. "Compressor"
    selectedBrand = data['brand'] as String?;          // e.g. "Ekomak"
    selectedModel = data['model'] as String?;          // e.g. "CAD 200"

    _serialController.text = data['serialNumber'] ?? '';
    _invoiceNumberController.text = data['invoiceNumber'] ?? '';
    _deliveryNoteNumberController.text = data['deliveryNoteNumber'] ?? '';

    invoiceUrl = data['invoiceUrl'] ?? '';
    deliveryNoteUrl = data['deliveryNoteUrl'] ?? '';

    // New fields
    _linkedStatusController.text = data['linkedStatus'] ?? 'Not linked to PSA';
    _installationDateController.text =
        data['installationDate'] ?? 'not installed yet';
    _commissioningDateController.text =
        data['commissioningDate'] ?? 'Not commissioned yet';
    _functionalStatusController.text =
        data['functionalStatus'] ?? 'Not working';
  }

  // -------------------------------------------------------
  // Fetch all "equipment_definitions" for brand/model logic
  // -------------------------------------------------------
  Future<void> _fetchEquipmentDefinitions() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('equipment_definitions')
          .get();
      setState(() {
        definitions = snap.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching equipment_definitions: $e");
    }
  }

  // -------------------------------------------------------
  // brandList => from definitions that match selectedType
  // -------------------------------------------------------
  List<String> get brandList {
    if (selectedType == null) return [];
    final filtered = definitions.where((def) {
      return (def['equipmentType'] ?? '') == selectedType;
    });
    final setOfBrands = filtered
        .map((def) => (def['brand'] ?? '') as String)
        .where((b) => b.isNotEmpty)
        .toSet();
    final sortedBrands = setOfBrands.toList()..sort();
    return sortedBrands;
  }

  // -------------------------------------------------------
  // modelList => from definitions that match type + brand
  // -------------------------------------------------------
  List<String> get modelList {
    if (selectedType == null || selectedBrand == null) return [];
    final filtered = definitions.where((def) {
      final eqType = (def['equipmentType'] ?? '') as String;
      final brand = (def['brand'] ?? '') as String;
      return eqType == selectedType && brand == selectedBrand;
    });
    final setOfModels = filtered
        .map((def) => (def['model'] ?? '') as String)
        .where((m) => m.isNotEmpty)
        .toSet();
    final sortedModels = setOfModels.toList()..sort();
    return sortedModels;
  }

  // -------------------------------------------------------
  // pickAndUploadFile => for invoice/delivery note
  // -------------------------------------------------------
  Future<String?> _pickAndUploadFile(String label) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.first;
      final fileName = picked.name;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('acquired_equipment_files')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = picked.bytes;
        if (bytes == null) return null;
        uploadTask = storageRef.putData(bytes);
      } else {
        final path = picked.path;
        if (path == null) return null;
        final file = File(path);
        uploadTask = storageRef.putFile(file);
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      debugPrint("[EditAcquired] Error uploading $label: $e");
      return null;
    }
  }

  // -------------------------------------------------------
  // Save changes => doc update
  // -------------------------------------------------------
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedType == null || selectedBrand == null || selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Type, Brand, and Model.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updateData = {
        // existing fields
        'equipmentType': selectedType,
        'brand': selectedBrand,
        'model': selectedModel,
        'serialNumber': _serialController.text.trim(),
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceUrl': invoiceUrl ?? '',
        'deliveryNoteUrl': deliveryNoteUrl ?? '',
        // We do NOT overwrite createdAt, we keep the original

        // new fields
        'linkedStatus': _linkedStatusController.text.trim(),
        'installationDate': _installationDateController.text.trim(),
        'commissioningDate': _commissioningDateController.text.trim(),
        'functionalStatus': _functionalStatusController.text.trim(),
        'deliveryNoteNumber': _deliveryNoteNumberController.text.trim(),
      };

      // Update doc in Firestore
      await FirebaseFirestore.instance
          .collection('acquired_equipments')
          .doc(widget.docId)
          .update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Equipment updated successfully!'),
        ),
      );
      Navigator.pop(context); // go back
    } catch (e) {
      debugPrint('[EditAcquired] Error updating equipment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // -------------------------------------------------------
  // Build UI
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Acquired Equipment'),
        backgroundColor: const Color(0xFF002244),
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 1) Equipment Type
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Equipment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: fixedTypes.map((t) {
                      return DropdownMenuItem(value: t, child: Text(t));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedType = val;
                        // reset brand/model if type changes
                        selectedBrand = null;
                        selectedModel = null;
                      });
                    },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Please select equipment type'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 2) Brand => from brandList
                  DropdownButtonFormField<String>(
                    value: selectedBrand,
                    decoration: const InputDecoration(
                      labelText: 'Brand',
                      border: OutlineInputBorder(),
                    ),
                    items: brandList.map((b) {
                      return DropdownMenuItem(value: b, child: Text(b));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedBrand = val;
                        selectedModel = null;
                      });
                    },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Please select a brand'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // 3) Model => from modelList
                  DropdownButtonFormField<String>(
                    value: selectedModel,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      border: OutlineInputBorder(),
                    ),
                    items: modelList.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedModel = val;
                      });
                    },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Please select a model'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Serial
                  TextFormField(
                    controller: _serialController,
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Please enter a serial number'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Invoice Number
                  TextFormField(
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delivery Note Number
                  TextFormField(
                    controller: _deliveryNoteNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Note Number (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Linked Status
                  TextFormField(
                    controller: _linkedStatusController,
                    decoration: const InputDecoration(
                      labelText: 'Linked Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Installation Date
                  TextFormField(
                    controller: _installationDateController,
                    decoration: const InputDecoration(
                      labelText: 'Installation Date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Commissioning Date
                  TextFormField(
                    controller: _commissioningDateController,
                    decoration: const InputDecoration(
                      labelText: 'Commissioning Date',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Functional Status
                  TextFormField(
                    controller: _functionalStatusController,
                    decoration: const InputDecoration(
                      labelText: 'Functional Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Invoice file
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002244),
                        ),
                        onPressed: () async {
                          final url =
                          await _pickAndUploadFile('Invoice');
                          if (url != null) {
                            setState(() => invoiceUrl = url);
                          }
                        },
                        child: const Text('Change Invoice File'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: (invoiceUrl == null || invoiceUrl!.isEmpty)
                            ? Text(
                          'Current: ${(widget.docData['invoiceUrl'] ?? 'None')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                            : Text(
                          'New Invoice: $invoiceUrl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Delivery Note file
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002244),
                        ),
                        onPressed: () async {
                          final url =
                          await _pickAndUploadFile('Delivery Note');
                          if (url != null) {
                            setState(() => deliveryNoteUrl = url);
                          }
                        },
                        child: const Text('Change Delivery Note File'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: (deliveryNoteUrl == null ||
                            deliveryNoteUrl!.isEmpty)
                            ? Text(
                          'Current: ${(widget.docData['deliveryNoteUrl'] ?? 'None')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                            : Text(
                          'New Delivery Note: $deliveryNoteUrl',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002244),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _saveChanges,
                      child: const Text(
                        'Update Equipment',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
