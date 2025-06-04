import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class BrandModelCreationPage extends StatefulWidget {
  const BrandModelCreationPage({Key? key}) : super(key: key);

  @override
  _BrandModelCreationPageState createState() => _BrandModelCreationPageState();
}

class _BrandModelCreationPageState extends State<BrandModelCreationPage> {
  final _formKey = GlobalKey<FormState>();

  // Dropdown values.
  String? selectedBrand;
  String? selectedEquipmentType;

  // Text controllers.
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _dimensionXController = TextEditingController();
  final TextEditingController _dimensionYController = TextEditingController();
  final TextEditingController _dimensionZController = TextEditingController();
  final TextEditingController _powerCapacityController = TextEditingController();
  final TextEditingController _voltageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Spare parts (each is a map with fields: name, brand, model, serialNumber, datasheetURL).
  List<Map<String, dynamic>> spareParts = [];

  // Service kits: each is a map with fields: name, globalDocument, items[].
  List<Map<String, dynamic>> serviceKits = [];

  // Equipment documents: each is a map with fields: docType, downloadURL, fileName.
  List<Map<String, dynamic>> equipmentDocuments = [];

  // Equipment image download URL.
  String? imageUrl;

  bool _isLoading = false;

  // --------------------------------------------------------
  // Fetch brand names from 'partners' collection.
  // --------------------------------------------------------
  Future<List<String>> _fetchBrands() async {
    final querySnapshot =
    await FirebaseFirestore.instance.collection('partners').get();
    final brandList = <String>[];
    for (final doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['supplierDetails'] != null && data['supplierDetails'] is Map) {
        final supplierDetails = data['supplierDetails'] as Map;
        final brandName = supplierDetails['brandName'];
        if (brandName != null && brandName is String && brandName.isNotEmpty) {
          brandList.add(brandName);
        }
      }
    }
    return brandList.toSet().toList();
  }

  // --------------------------------------------------------
  // Static Equipment Types
  // --------------------------------------------------------
  final List<String> equipmentTypes = [
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
    'MGPS'
  ];

  // --------------------------------------------------------
  // Helper to upload files to Firebase
  // --------------------------------------------------------
  Future<String?> _uploadFile({
    File? file,
    Uint8List? bytes,
    required String fileName,
    required String storageFolder,
  }) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(storageFolder)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      UploadTask uploadTask;
      if (kIsWeb && bytes != null) {
        uploadTask = storageRef.putData(bytes);
      } else if (!kIsWeb && file != null) {
        uploadTask = storageRef.putFile(file);
      } else {
        return null;
      }

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadURL = await snapshot.ref.getDownloadURL();
      return downloadURL;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  // --------------------------------------------------------
  // Spare Part Dialog (with Serial Number added)
  // --------------------------------------------------------
  Future<void> _showAddSparePartDialog() async {
    final TextEditingController sparePartNameController =
    TextEditingController();
    final TextEditingController sparePartBrandController =
    TextEditingController();
    final TextEditingController sparePartModelController =
    TextEditingController();
    // NEW: Controller for the Spare Part Serial Number
    final TextEditingController sparePartSerialNumberController =
    TextEditingController();

    File? selectedFile;
    Uint8List? fileBytes;
    String? datasheetUrl;
    String? pickedFileName; // For web usage

    Future<void> _pickDatasheetFile() async {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          fileBytes = result.files.first.bytes;
          pickedFileName = result.files.first.name;
        } else {
          selectedFile = File(result.files.single.path!);
        }
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Add Spare Part',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: sparePartNameController,
                    decoration: const InputDecoration(
                      labelText: 'Spare Part Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sparePartBrandController,
                    decoration: const InputDecoration(
                      labelText: 'Spare Part Brand',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: sparePartModelController,
                    decoration: const InputDecoration(
                      labelText: 'Spare Part Model',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // NEW: Field for the Serial Number
                  TextField(
                    controller: sparePartSerialNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Spare Part Serial Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _pickDatasheetFile();
                      setDialogState(() {}); // Refresh UI
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach Datasheet (Optional)'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && fileBytes != null)
                    Text('Selected: ${pickedFileName ?? "Unknown"}')
                  else if (!kIsWeb && selectedFile != null)
                    Text('Selected: ${selectedFile!.path.split('/').last}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002244),
                ),
                onPressed: () async {
                  final name = sparePartNameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a spare part name.'),
                      ),
                    );
                    return;
                  }

                  // Upload datasheet if selected
                  if ((kIsWeb && fileBytes != null) ||
                      (!kIsWeb && selectedFile != null)) {
                    final fileName = kIsWeb
                        ? (pickedFileName ??
                        'sparepart_${DateTime.now().millisecondsSinceEpoch}.dat')
                        : selectedFile!.path.split('/').last;
                    datasheetUrl = await _uploadFile(
                      bytes: kIsWeb ? fileBytes : null,
                      file: kIsWeb ? null : selectedFile,
                      fileName: fileName,
                      storageFolder: 'spare_parts',
                    );
                  }

                  setState(() {
                    spareParts.add({
                      'name': name,
                      'brand': sparePartBrandController.text.trim(),
                      'model': sparePartModelController.text.trim(),
                      // NEW: Add the serial number
                      'serialNumber':
                      sparePartSerialNumberController.text.trim(),
                      'datasheetURL': datasheetUrl ?? '',
                    });
                  });

                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSparePart() async {
    await _showAddSparePartDialog();
  }

  // --------------------------------------------------------
  // Service Kit Item Dialog
  // --------------------------------------------------------
  Future<Map<String, dynamic>?> _showAddServiceKitItemDialog() async {
    final TextEditingController itemNameController = TextEditingController();
    final TextEditingController itemBrandController = TextEditingController();
    final TextEditingController itemModelController = TextEditingController();
    final TextEditingController itemChangePeriodController =
    TextEditingController();

    File? itemDocFile;
    Uint8List? itemDocBytes;
    String? itemDocUrl;
    String? pickedItemDocFileName;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Add Service Kit Item',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: itemNameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: itemBrandController,
                    decoration: const InputDecoration(
                      labelText: 'Item Brand',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: itemModelController,
                    decoration: const InputDecoration(
                      labelText: 'Item Model',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: itemChangePeriodController,
                    decoration: const InputDecoration(
                      labelText: 'Change Period (hours)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        type: FileType.any,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        if (kIsWeb) {
                          itemDocBytes = result.files.first.bytes;
                          pickedItemDocFileName = result.files.first.name;
                        } else {
                          itemDocFile = File(result.files.single.path!);
                        }
                        setDialogState(() {});
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach Datasheet (Optional)'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && itemDocBytes != null)
                    Text('Selected: ${pickedItemDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && itemDocFile != null)
                    Text('Selected: ${itemDocFile!.path.split('/').last}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002244),
                ),
                onPressed: () async {
                  final itemName = itemNameController.text.trim();
                  if (itemName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter an item name.'),
                      ),
                    );
                    return;
                  }

                  // Upload item datasheet if selected
                  if ((kIsWeb && itemDocBytes != null) ||
                      (!kIsWeb && itemDocFile != null)) {
                    final fileName = kIsWeb
                        ? (pickedItemDocFileName ??
                        'servicekititem_${DateTime.now().millisecondsSinceEpoch}.dat')
                        : itemDocFile!.path.split('/').last;
                    itemDocUrl = await _uploadFile(
                      file: kIsWeb ? null : itemDocFile,
                      bytes: kIsWeb ? itemDocBytes : null,
                      fileName: fileName,
                      storageFolder: 'service_kit_items',
                    );
                  }

                  final itemData = {
                    'name': itemName,
                    'brand': itemBrandController.text.trim(),
                    'model': itemModelController.text.trim(),
                    'changePeriod': itemChangePeriodController.text.trim(),
                    'datasheetURL': itemDocUrl ?? '',
                  };
                  Navigator.pop(context, itemData);
                },
                child: const Text('Add Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------
  // Service Kit Dialog
  // --------------------------------------------------------
  Future<void> _showAddServiceKitDialog() async {
    final TextEditingController serviceKitNameController =
    TextEditingController();
    File? globalDocFile;
    Uint8List? globalDocBytes;
    String? globalDocUrl;
    String? pickedGlobalDocFileName;
    List<Map<String, dynamic>> kitItems = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Add Service Kit',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: serviceKitNameController,
                    decoration: const InputDecoration(
                      labelText: 'Service Kit Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        type: FileType.any,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        if (kIsWeb) {
                          globalDocBytes = result.files.first.bytes;
                          pickedGlobalDocFileName = result.files.first.name;
                        } else {
                          globalDocFile = File(result.files.single.path!);
                        }
                        setDialogState(() {});
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Attach Global Document (Optional)'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && globalDocBytes != null)
                    Text('Selected: ${pickedGlobalDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && globalDocFile != null)
                    Text('Selected: ${globalDocFile!.path.split('/').last}'),
                  const SizedBox(height: 12),
                  if (kitItems.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Items:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ...kitItems.map((item) {
                          return ListTile(
                            title: Text(item['name'] ?? ''),
                            subtitle: Text(
                                'Brand: ${item['brand']}, Model: ${item['model']}, Change: ${item['changePeriod']} h'),
                          );
                        }).toList(),
                      ],
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final newItem = await _showAddServiceKitItemDialog();
                      if (newItem != null) {
                        kitItems.add(newItem);
                        setDialogState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002244),
                    ),
                    child: const Text('Add Service Kit Item'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002244),
                ),
                onPressed: () async {
                  final kitName = serviceKitNameController.text.trim();
                  if (kitName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a service kit name.'),
                      ),
                    );
                    return;
                  }

                  // Upload global doc if selected
                  if ((kIsWeb && globalDocBytes != null) ||
                      (!kIsWeb && globalDocFile != null)) {
                    final fileName = kIsWeb
                        ? (pickedGlobalDocFileName ??
                        'servicekit_${DateTime.now().millisecondsSinceEpoch}.dat')
                        : globalDocFile!.path.split('/').last;
                    globalDocUrl = await _uploadFile(
                      bytes: kIsWeb ? globalDocBytes : null,
                      file: kIsWeb ? null : globalDocFile,
                      fileName: fileName,
                      storageFolder: 'service_kit_global',
                    );
                  }
                  final serviceKit = {
                    'name': kitName,
                    'globalDocument': globalDocUrl ?? '',
                    'items': kitItems,
                  };
                  setState(() {
                    serviceKits.add(serviceKit);
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add Service Kit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addServiceKit() async {
    await _showAddServiceKitDialog();
  }

  // --------------------------------------------------------
  // Equipment Documents Dialog
  // --------------------------------------------------------
  Future<void> _showAddEquipmentDocumentDialog() async {
    final List<String> docTypes = [
      'Certificate',
      'Service Manual',
      'User Manual',
      'Datasheet',
      'Other'
    ];
    String? selectedDocType;
    File? docFile;
    Uint8List? docBytes;
    String? docDownloadUrl;
    String? pickedDocFileName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text(
              'Add Equipment Document',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDocType,
                    items: docTypes
                        .map(
                          (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedDocType = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Pick Document File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002244),
                    ),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        type: FileType.any,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        if (kIsWeb) {
                          docBytes = result.files.first.bytes;
                          pickedDocFileName = result.files.first.name;
                        } else {
                          docFile = File(result.files.single.path!);
                        }
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && docBytes != null)
                    Text('Selected: ${pickedDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && docFile != null)
                    Text('Selected: ${docFile!.path.split('/').last}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF002244),
                ),
                onPressed: () async {
                  if (selectedDocType == null || selectedDocType!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a document type.')),
                    );
                    return;
                  }
                  final fileName = kIsWeb
                      ? (pickedDocFileName ??
                      'doc_${DateTime.now().millisecondsSinceEpoch}.dat')
                      : docFile!.path.split('/').last;
                  docDownloadUrl = await _uploadFile(
                    file: kIsWeb ? null : docFile,
                    bytes: kIsWeb ? docBytes : null,
                    fileName: fileName,
                    storageFolder: 'equipment_documents',
                  );
                  setState(() {
                    equipmentDocuments.add({
                      'docType': selectedDocType,
                      'downloadURL': docDownloadUrl,
                      'fileName': fileName,
                    });
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add Document'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addEquipmentDocument() async {
    await _showAddEquipmentDocumentDialog();
  }

  // --------------------------------------------------------
  // Select & Upload Equipment Image
  // --------------------------------------------------------
  Future<void> _selectImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
    );
    if (result != null && result.files.isNotEmpty) {
      final fileName = result.files.first.name;
      if (kIsWeb) {
        final Uint8List? fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          final downloadURL = await _uploadFile(
            bytes: fileBytes,
            fileName: fileName,
            storageFolder: 'equipment_images',
          );
          if (downloadURL != null) {
            setState(() {
              imageUrl = downloadURL;
            });
          }
        }
      } else {
        final path = result.files.first.path;
        if (path != null) {
          final file = File(path);
          final downloadURL = await _uploadFile(
            file: file,
            fileName: fileName,
            storageFolder: 'equipment_images',
          );
          if (downloadURL != null) {
            setState(() {
              imageUrl = downloadURL;
            });
          }
        }
      }
    }
  }

  // --------------------------------------------------------
  // Save to Firestore
  // --------------------------------------------------------
  Future<void> _saveEquipmentDefinition() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final data = {
          'brand': selectedBrand,
          'equipmentType': selectedEquipmentType,
          'model': _modelController.text.trim(),
          'weight': _weightController.text.trim(),
          'dimensionX': _dimensionXController.text.trim(),
          'dimensionY': _dimensionYController.text.trim(),
          'dimensionZ': _dimensionZController.text.trim(),
          'powerCapacity': _powerCapacityController.text.trim(),
          'voltage': _voltageController.text.trim(),
          'spareParts': spareParts,
          'serviceKits': serviceKits,
          'equipmentDocuments': equipmentDocuments,
          'imageUrl': imageUrl,
          'description': _descriptionController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('equipment_definitions')
            .add(data);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment Definition saved successfully!')),
        );
        Navigator.of(context).pop();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $error')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _weightController.dispose();
    _dimensionXController.dispose();
    _dimensionYController.dispose();
    _dimensionZController.dispose();
    _powerCapacityController.dispose();
    _voltageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // Build UI
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Equipment Definition'),
        backgroundColor: const Color(0xFF002244),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004466), Color(0xFF002244)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Define New Brand & Model',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fill in general specifications, attach documents, and define spare parts or service kits.',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // SECTION 1: Brand & Equipment Type
                    _buildSectionTitle('General Information'),
                    const SizedBox(height: 8),
                    FutureBuilder<List<String>>(
                      future: _fetchBrands(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Text('Error: ${snapshot.error}');
                        }
                        final brandList = snapshot.data ?? [];
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: selectedBrand,
                              items: brandList
                                  .map(
                                    (b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b),
                                ),
                              )
                                  .toList(),
                              onChanged: (val) {
                                setState(() => selectedBrand = val);
                              },
                              validator: (val) =>
                              (val == null || val.isEmpty)
                                  ? 'Please select a brand'
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Select Brand *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedEquipmentType,
                      items: equipmentTypes
                          .map(
                            (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                          .toList(),
                      onChanged: (val) {
                        setState(() => selectedEquipmentType = val);
                      },
                      validator: (val) =>
                      (val == null || val.isEmpty)
                          ? 'Please select equipment type'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Type of Equipment *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Model *',
                        hintText: 'Enter model name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) =>
                      (val == null || val.isEmpty)
                          ? 'Please enter the model'
                          : null,
                    ),
                    const SizedBox(height: 24),

                    // SECTION 2: Technical Specs
                    _buildSectionTitle('Technical Specifications'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDimensionField(
                            label: 'Dimension X (cm)',
                            controller: _dimensionXController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDimensionField(
                            label: 'Dimension Y (cm)',
                            controller: _dimensionYController,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildDimensionField(
                            label: 'Dimension Z (cm)',
                            controller: _dimensionZController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _powerCapacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Power Capacity (kW)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _voltageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Voltage (V)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SECTION 3: Image & Docs
                    _buildSectionTitle('Images & Documents'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _selectImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002244),
                          ),
                          icon: const Icon(Icons.image),
                          label: const Text('Equipment Image'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: imageUrl == null
                              ? const Text('No image selected')
                              : Text(
                            imageUrl!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addEquipmentDocument,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          '+ Add Equipment Document',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (equipmentDocuments.isNotEmpty)
                      ...equipmentDocuments.map((doc) {
                        return ListTile(
                          title: Text(doc['docType']?.toString() ??
                              'No Type'),
                          subtitle: Text(doc['fileName'] ?? ''),
                          trailing: (doc['downloadURL'] != null &&
                              (doc['downloadURL'] as String)
                                  .isNotEmpty)
                              ? ElevatedButton.icon(
                            onPressed: () async {
                              // Implement your download logic
                            },
                            icon: const Icon(Icons.download,
                                size: 16),
                            label: const Text("Download",
                                style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          )
                              : null,
                        );
                      }).toList(),
                    const Divider(height: 32),

                    // SECTION 4: Spare Parts
                    _buildSectionTitle('Spare Parts'),
                    const SizedBox(height: 8),
                    if (spareParts.isNotEmpty)
                      Column(
                        children: spareParts.map((sp) {
                          final name = sp['name'] ?? '';
                          final brand = sp['brand'] ?? '';
                          final model = sp['model'] ?? '';
                          final serialNumber = sp['serialNumber'] ?? '';
                          final datasheetURL = sp['datasheetURL'] ?? '';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 0),
                            elevation: 2,
                            child: ListTile(
                              // Display the Serial Number here
                              title: Text(
                                  '$name ($brand / $model) - SN: $serialNumber'),
                              subtitle: datasheetURL.isNotEmpty
                                  ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Datasheet: '),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      // Implement download
                                    },
                                    icon: const Icon(Icons.download,
                                        size: 16),
                                    label: const Text(
                                      "Download",
                                      style:
                                      TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 8,
                                          vertical: 4),
                                    ),
                                  ),
                                ],
                              )
                                  : const Text('No datasheet'),
                            ),
                          );
                        }).toList(),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addSparePart,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          '+ Add Spare Part',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Divider(height: 32),

                    // SECTION 5: Service Kits
                    _buildSectionTitle('Service Kits'),
                    const SizedBox(height: 8),
                    if (serviceKits.isNotEmpty)
                      Column(
                        children: serviceKits.map((kit) {
                          final name = kit['name'] ?? '';
                          final doc = kit['globalDocument'] ?? '';
                          return Card(
                            margin:
                            const EdgeInsets.symmetric(vertical: 4),
                            elevation: 2,
                            child: ExpansionTile(
                              title: Text(name),
                              subtitle: doc.isNotEmpty
                                  ? Text('Global Doc: $doc')
                                  : const Text('No Global Document'),
                              children: [
                                if (kit['items'] != null)
                                  ...((kit['items'] as List).map((item) {
                                    return ListTile(
                                      title: Text(
                                          item['name']?.toString() ?? ''),
                                      subtitle: Text(
                                          'Brand: ${item['brand']}, Model: ${item['model']}, Change: ${item['changePeriod']}h'),
                                    );
                                  }).toList()),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addServiceKit,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          '+ Add Service Kit',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const Divider(height: 32),

                    // SECTION 6: Description
                    _buildSectionTitle('Equipment Description'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Enter equipment definition description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveEquipmentDefinition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002244),
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Add Equipment Definition',
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        const Icon(Icons.label, color: Color(0xFF002244)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF002244),
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
