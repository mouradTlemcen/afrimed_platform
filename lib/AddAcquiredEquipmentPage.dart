import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class AddAcquiredEquipmentPage extends StatefulWidget {
  const AddAcquiredEquipmentPage({Key? key}) : super(key: key);

  @override
  _AddAcquiredEquipmentPageState createState() =>
      _AddAcquiredEquipmentPageState();
}

class _AddAcquiredEquipmentPageState extends State<AddAcquiredEquipmentPage> {
  final _formKey = GlobalKey<FormState>();

  // -------------------------------------------------
  // 1) Fixed list of 18 equipment types
  // -------------------------------------------------
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
    'Vacume pump',

  ];

  // 2) All docs from equipment_definitions
  List<Map<String, dynamic>> definitions = [];

  // 3) Selected dropdown values
  String? selectedType;
  String? selectedBrand;
  String? selectedModel;

  // -------------------------------------------------
  // Existing text fields
  // -------------------------------------------------
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _invoiceNumberController = TextEditingController();

  // -------------------------------------------------
  // NEW: DeliveryNoteNumber text field
  // -------------------------------------------------
  final TextEditingController _deliveryNoteNumberController =
  TextEditingController();

  // For (optional) invoice/delivery note files
  String? invoiceUrl;
  String? deliveryNoteUrl;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchEquipmentDefinitions();
  }

  // --------------------------------------------------------
  // Fetch docs from "equipment_definitions" for brand/model
  // --------------------------------------------------------
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
      debugPrint("[AddAcquired] Fetched ${definitions.length} definitions total.");
    } catch (e) {
      debugPrint("Error fetching equipment_definitions: $e");
    }
  }

  // --------------------------------------------------------
  // brandList => from docs that match selectedType
  // --------------------------------------------------------
  List<String> get brandList {
    if (selectedType == null) {
      debugPrint("[brandList] selectedType == null => empty list");
      return [];
    }
    final filtered = definitions.where((def) {
      final eqType = (def['equipmentType'] ?? '') as String;
      return eqType == selectedType;
    }).toList();

    debugPrint("[brandList] Found ${filtered.length} docs matching type=$selectedType");
    for (var doc in filtered) {
      debugPrint(
          " brand='${doc['brand']}', eqType='${doc['equipmentType']}', model='${doc['model']}'");
    }

    final brandSet = filtered
        .map((def) => (def['brand'] ?? '') as String)
        .where((b) => b.isNotEmpty)
        .toSet();
    final sortedBrands = brandSet.toList()..sort();

    debugPrint("[brandList] => unique brands: $sortedBrands");
    return sortedBrands;
  }

  // --------------------------------------------------------
  // modelList => from docs matching selectedType + selectedBrand
  // --------------------------------------------------------
  List<String> get modelList {
    if (selectedType == null || selectedBrand == null) {
      debugPrint("[modelList] no selectedType/selectedBrand => empty list");
      return [];
    }
    final filtered = definitions.where((def) {
      final eqType = (def['equipmentType'] ?? '') as String;
      final brand = (def['brand'] ?? '') as String;
      return eqType == selectedType && brand == selectedBrand;
    }).toList();

    debugPrint(
        "[modelList] Found ${filtered.length} docs matching type=$selectedType brand=$selectedBrand");
    for (var doc in filtered) {
      debugPrint(
          " brand='${doc['brand']}', eqType='${doc['equipmentType']}', model='${doc['model']}'");
    }

    final modelSet = filtered
        .map((def) => (def['model'] ?? '') as String)
        .where((m) => m.isNotEmpty)
        .toSet();
    final sortedModels = modelSet.toList()..sort();

    debugPrint("[modelList] => unique models: $sortedModels");
    return sortedModels;
  }

  // --------------------------------------------------------
  // pickAndUploadFile => for invoice or delivery note
  // --------------------------------------------------------
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
      debugPrint("[AddAcquired] Error uploading $label: $e");
      return null;
    }
  }

  // --------------------------------------------------------
  // Save doc => same structure plus new fields:
  //  linkedStatus, status, installationDate, commissioningDate,
  //  functionalStatus, deliveryNoteNumber
  // plus existing fields
  // --------------------------------------------------------
  Future<void> _saveAcquiredEquipment() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedType == null || selectedBrand == null || selectedModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Type, Brand, and Model.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        // existing fields
        'equipmentType': selectedType,
        'brand': selectedBrand,
        'model': selectedModel,
        'serialNumber': _serialController.text.trim(),
        'invoiceNumber': _invoiceNumberController.text.trim(),
        'invoiceUrl': invoiceUrl ?? '',
        'deliveryNoteUrl': deliveryNoteUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),

        // NEW FIELDS (hard-coded or from user input):
        'linkedStatus': "Not linked to PSA",
        // 'status': "not installed yet", // REMOVED
        'installationDate': "not installed yet", // if you want a separate field
        'commissioningDate': "Not commissioned yet",
        'functionalStatus': "Not working",

        'deliveryNoteNumber': _deliveryNoteNumberController.text.trim(),
      };

      await FirebaseFirestore.instance
          .collection('acquired_equipments')
          .add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acquired equipment saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('[AddAcquired] Error saving equipment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --------------------------------------------------------
  // UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Acquired Equipment'),
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
                  // 1) Equipment Type => from fixed list
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Equipment Type',
                      border: OutlineInputBorder(),
                    ),
                    items: fixedTypes.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedType = val;
                        selectedBrand = null;
                        selectedModel = null;
                      });
                      debugPrint("[AddAcquired] selectedType=$val");
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
                      return DropdownMenuItem(
                        value: b,
                        child: Text(b),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedBrand = val;
                        selectedModel = null;
                      });
                      debugPrint("[AddAcquired] selectedBrand=$val");
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
                      return DropdownMenuItem(
                        value: m,
                        child: Text(m),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedModel = val;
                      });
                      debugPrint("[AddAcquired] selectedModel=$val");
                    },
                    validator: (val) => (val == null || val.isEmpty)
                        ? 'Please select a model'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Serial Number
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

                  // Invoice Number field
                  TextFormField(
                    controller: _invoiceNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // NEW: Delivery Note Number field
                  TextFormField(
                    controller: _deliveryNoteNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Note Number (Optional)',
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
                          final url = await _pickAndUploadFile('Invoice');
                          if (url != null) {
                            setState(() => invoiceUrl = url);
                            debugPrint("[AddAcquired] invoiceUrl=$url");
                          }
                        },
                        child: const Text('Upload Invoice (Optional)'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: invoiceUrl == null
                            ? const Text('No invoice file selected')
                            : Text(
                          'Invoice: $invoiceUrl',
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
                            debugPrint(
                                "[AddAcquired] deliveryNoteUrl=$url");
                          }
                        },
                        child: const Text('Upload Delivery Note (Optional)'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: deliveryNoteUrl == null
                            ? const Text('No delivery note selected')
                            : Text(
                          'Delivery Note: $deliveryNoteUrl',
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
                      onPressed: _saveAcquiredEquipment,
                      child: const Text(
                        'Save Acquired Equipment',
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
