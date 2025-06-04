import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';

class EquipmentUpdatePage extends StatefulWidget {
  final Map<String, dynamic> equipmentData;
  final String equipmentId;

  const EquipmentUpdatePage({
    Key? key,
    required this.equipmentData,
    required this.equipmentId,
  }) : super(key: key);

  @override
  _EquipmentUpdatePageState createState() => _EquipmentUpdatePageState();
}

class _EquipmentUpdatePageState extends State<EquipmentUpdatePage> {
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

  // Spare parts (each is a map with fields: name, brand, model, datasheetURL).
  List<Map<String, dynamic>> spareParts = [];

  // Service kits: each is a map with fields: name, globalDocument, items[].
  // Each item in items[] is a map with fields: name, brand, model, changePeriod, datasheetURL.
  List<Map<String, dynamic>> serviceKits = [];

  // Equipment documents: each is a map with fields: docType, downloadURL, fileName.
  List<Map<String, dynamic>> equipmentDocuments = [];

  // Equipment image download URL.
  String? imageUrl;

  bool _isLoading = false;

  // --------------------------------------------------------
  // Lifecycle: initState - populate fields from equipmentData
  // --------------------------------------------------------
  @override
  void initState() {
    super.initState();
    final data = widget.equipmentData;

    selectedBrand = data['brand'];
    selectedEquipmentType = data['equipmentType'];

    _modelController.text = data['model'] ?? '';
    _weightController.text = data['weight'] ?? '';
    _dimensionXController.text = data['dimensionX'] ?? '';
    _dimensionYController.text = data['dimensionY'] ?? '';
    _dimensionZController.text = data['dimensionZ'] ?? '';
    _powerCapacityController.text = data['powerCapacity'] ?? '';
    _voltageController.text = data['voltage'] ?? '';
    _descriptionController.text = data['description'] ?? '';

    spareParts = (data['spareParts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    serviceKits =
        (data['serviceKits'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    equipmentDocuments = (data['equipmentDocuments'] as List?)
        ?.cast<Map<String, dynamic>>() ??
        [];

    imageUrl = data['imageUrl'];
  }

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
  // Static Equipment Types List.
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
  // Helper to upload file to Firebase Storage
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
  // Spare Part Dialog (Add or Edit)
  // --------------------------------------------------------
  Future<void> _showAddOrEditSparePartDialog({int? editIndex}) async {
    // If editIndex is null => "Add"
    // Otherwise => "Edit" existing item
    final isEdit = editIndex != null;
    final existingItem = isEdit ? spareParts[editIndex!] : <String, dynamic>{};

    final TextEditingController sparePartNameController =
    TextEditingController(text: existingItem['name'] ?? '');
    final TextEditingController sparePartBrandController =
    TextEditingController(text: existingItem['brand'] ?? '');
    final TextEditingController sparePartModelController =
    TextEditingController(text: existingItem['model'] ?? '');

    File? selectedFile;
    Uint8List? fileBytes;
    String? datasheetUrl = existingItem['datasheetURL'] ?? '';
    String? pickedFileName;

    // Helper to pick a file
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
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Spare Part' : 'Add Spare Part'),
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
                  ElevatedButton(
                    onPressed: () async {
                      await _pickDatasheetFile();
                      setDialogState(() {});
                    },
                    child: const Text('Pick Datasheet (Optional)'),
                  ),
                  const SizedBox(height: 8),

                  // Fix #1: Null‐aware check for datasheetUrl
                  if (!isEdit && (datasheetUrl?.isNotEmpty ?? false))
                    Text('Existing datasheet: $datasheetUrl'),

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
              TextButton(
                onPressed: () async {
                  final name = sparePartNameController.text.trim();
                  final brand = sparePartBrandController.text.trim();
                  final model = sparePartModelController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a spare part name.'),
                      ),
                    );
                    return;
                  }

                  // If a new file was picked, upload it
                  if ((kIsWeb && fileBytes != null) ||
                      (!kIsWeb && selectedFile != null)) {
                    final String finalFileName = kIsWeb
                        ? pickedFileName ??
                        'sparepart_${DateTime.now().millisecondsSinceEpoch}.dat'
                        : selectedFile!.path.split('/').last;

                    datasheetUrl = await _uploadFile(
                      bytes: kIsWeb ? fileBytes : null,
                      file: kIsWeb ? null : selectedFile,
                      fileName: finalFileName,
                      storageFolder: 'spare_parts',
                    );
                  }

                  final newPartData = {
                    'name': name,
                    'brand': brand,
                    'model': model,
                    'datasheetURL': datasheetUrl ?? '',
                  };

                  setState(() {
                    if (isEdit) {
                      spareParts[editIndex!] = newPartData;
                    } else {
                      spareParts.add(newPartData);
                    }
                  });

                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addSparePart() async {
    await _showAddOrEditSparePartDialog();
  }

  // --------------------------------------------------------
  // Service Kit Item Dialog
  // --------------------------------------------------------
  Future<Map<String, dynamic>?> _showAddOrEditServiceKitItemDialog(
      {Map<String, dynamic>? existingItem}) async {
    final bool isEdit = existingItem != null;
    final itemData = existingItem ?? <String, dynamic>{};

    final TextEditingController itemNameController =
    TextEditingController(text: itemData['name'] ?? '');
    final TextEditingController itemBrandController =
    TextEditingController(text: itemData['brand'] ?? '');
    final TextEditingController itemModelController =
    TextEditingController(text: itemData['model'] ?? '');
    final TextEditingController itemChangePeriodController =
    TextEditingController(text: itemData['changePeriod'] ?? '');

    File? itemDocFile;
    Uint8List? itemDocBytes;
    String? itemDocUrl = itemData['datasheetURL'] ?? '';
    String? pickedItemDocFileName;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Service Kit Item' : 'Add Service Kit Item'),
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
                  const SizedBox(height: 8),
                  ElevatedButton(
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
                    child: const Text('Pick Datasheet (Optional)'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && itemDocBytes != null)
                    Text('Selected: ${pickedItemDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && itemDocFile != null)
                    Text('Selected: ${itemDocFile!.path.split('/').last}'),

                  // If editing and there's an existing datasheet:
                  if (isEdit && (itemDocUrl?.isNotEmpty ?? false))
                    Text('Existing datasheet: $itemDocUrl'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final itemName = itemNameController.text.trim();
                  if (itemName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter an item name.')),
                    );
                    return;
                  }

                  // If new file was picked, upload it
                  if ((kIsWeb && itemDocBytes != null) ||
                      (!kIsWeb && itemDocFile != null)) {
                    final fileName = kIsWeb
                        ? (pickedItemDocFileName ??
                        'servicekititem_${DateTime.now().millisecondsSinceEpoch}.dat')
                        : itemDocFile!.path.split('/').last;

                    itemDocUrl = await _uploadFile(
                      bytes: kIsWeb ? itemDocBytes : null,
                      file: kIsWeb ? null : itemDocFile,
                      fileName: fileName,
                      storageFolder: 'service_kit_items',
                    );
                  }

                  final newItemData = {
                    'name': itemName,
                    'brand': itemBrandController.text.trim(),
                    'model': itemModelController.text.trim(),
                    'changePeriod': itemChangePeriodController.text.trim(),
                    'datasheetURL': itemDocUrl ?? '',
                  };
                  Navigator.pop(context, newItemData);
                },
                child: Text(isEdit ? 'Save' : 'Add Item'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------
  // Service Kit Dialog (Add or Edit)
  // --------------------------------------------------------
  Future<void> _showAddOrEditServiceKitDialog({int? editIndex}) async {
    final bool isEdit = editIndex != null;
    final existingKit = isEdit ? serviceKits[editIndex!] : <String, dynamic>{};

    final TextEditingController serviceKitNameController =
    TextEditingController(text: existingKit['name'] ?? '');
    File? globalDocFile;
    Uint8List? globalDocBytes;
    String? globalDocUrl = existingKit['globalDocument'] ?? '';
    String? pickedGlobalDocFileName;

    // The items inside the kit
    List<Map<String, dynamic>> kitItems =
        (existingKit['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Service Kit' : 'Add Service Kit'),
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
                  ElevatedButton(
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
                    child: const Text('Pick Global Document (Optional)'),
                  ),
                  const SizedBox(height: 4),
                  if (kIsWeb && globalDocBytes != null)
                    Text('Selected: ${pickedGlobalDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && globalDocFile != null)
                    Text('Selected: ${globalDocFile!.path.split('/').last}'),

                  // Fix #2: Null‐aware check for globalDocUrl
                  if (isEdit && (globalDocUrl?.isNotEmpty ?? false))
                    Text('Existing global document: $globalDocUrl'),

                  const SizedBox(height: 8),
                  if (kitItems.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Items:'),
                        ...kitItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return ListTile(
                            title: Text(item['name'] ?? ''),
                            subtitle: Text(
                              'Brand: ${item['brand']}, Model: ${item['model']}, Period: ${item['changePeriod']} h',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final updatedItem =
                                await _showAddOrEditServiceKitItemDialog(
                                    existingItem: item);
                                if (updatedItem != null) {
                                  setDialogState(() {
                                    kitItems[index] = updatedItem;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final newItem =
                      await _showAddOrEditServiceKitItemDialog();
                      if (newItem != null) {
                        setDialogState(() {
                          kitItems.add(newItem);
                        });
                      }
                    },
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
              TextButton(
                onPressed: () async {
                  final kitName = serviceKitNameController.text.trim();
                  if (kitName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter a service kit name.')),
                    );
                    return;
                  }

                  // If new global doc was picked, upload it
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
                  final newKit = {
                    'name': kitName,
                    'globalDocument': globalDocUrl ?? '',
                    'items': kitItems,
                  };

                  setState(() {
                    if (isEdit) {
                      serviceKits[editIndex!] = newKit;
                    } else {
                      serviceKits.add(newKit);
                    }
                  });
                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Save Kit' : 'Add Service Kit'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addServiceKit() async {
    await _showAddOrEditServiceKitDialog();
  }

  // --------------------------------------------------------
  // Equipment Documents Dialog (Add or Edit)
  // --------------------------------------------------------
  Future<void> _showAddOrEditEquipmentDocumentDialog({int? editIndex}) async {
    final bool isEdit = editIndex != null;
    final existingDoc =
    isEdit ? equipmentDocuments[editIndex!] : <String, dynamic>{};

    final List<String> docTypes = [
      'Certificate',
      'Service Manual',
      'User Manual',
      'Datasheet',
      'Other'
    ];
    String? selectedDocType = existingDoc['docType'];
    File? docFile;
    Uint8List? docBytes;
    String? docDownloadUrl = existingDoc['downloadURL'] ?? '';
    String? fileName = existingDoc['fileName'] ?? '';
    String? pickedDocFileName;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit
                ? 'Edit Equipment Document'
                : 'Add Equipment Document'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDocType,
                    items: docTypes
                        .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    ))
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
                  const SizedBox(height: 8),
                  ElevatedButton(
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
                    child: const Text('Pick Document File'),
                  ),
                  const SizedBox(height: 8),
                  if (kIsWeb && docBytes != null)
                    Text('Selected: ${pickedDocFileName ?? "Unknown"}')
                  else if (!kIsWeb && docFile != null)
                    Text('Selected: ${docFile!.path.split('/').last}'),

                  // Fix #3: Null‐aware check for docDownloadUrl
                  if (isEdit && (docDownloadUrl?.isNotEmpty ?? false))
                    Text('Existing file: $docDownloadUrl'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (selectedDocType == null || selectedDocType!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please select a document type.')),
                    );
                    return;
                  }

                  // If new file was picked, upload it
                  if ((kIsWeb && docBytes != null) ||
                      (!kIsWeb && docFile != null)) {
                    final finalFileName = kIsWeb
                        ? (pickedDocFileName ??
                        'doc_${DateTime.now().millisecondsSinceEpoch}.dat')
                        : docFile!.path.split('/').last;

                    final newUrl = await _uploadFile(
                      file: kIsWeb ? null : docFile,
                      bytes: kIsWeb ? docBytes : null,
                      fileName: finalFileName,
                      storageFolder: 'equipment_documents',
                    );
                    if (newUrl != null) {
                      docDownloadUrl = newUrl;
                      fileName = finalFileName;
                    }
                  }

                  final newDoc = {
                    'docType': selectedDocType,
                    'downloadURL': docDownloadUrl,
                    'fileName': fileName,
                  };

                  setState(() {
                    if (isEdit) {
                      equipmentDocuments[editIndex!] = newDoc;
                    } else {
                      equipmentDocuments.add(newDoc);
                    }
                  });

                  Navigator.pop(context);
                },
                child: Text(isEdit ? 'Save' : 'Add Document'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addEquipmentDocument() async {
    await _showAddOrEditEquipmentDocumentDialog();
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
      final pickedFileName = result.files.first.name;
      if (kIsWeb) {
        final Uint8List? fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          final downloadURL = await _uploadFile(
            bytes: fileBytes,
            fileName: pickedFileName,
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
            fileName: pickedFileName,
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
  // Save/Update Equipment Definition in Firestore
  // --------------------------------------------------------
  Future<void> _updateEquipmentDefinition() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final updatedData = {
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
          // Keep 'createdAt' if needed; below adds 'updatedAt':
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('equipment_definitions')
            .doc(widget.equipmentId)
            .update(updatedData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Equipment updated successfully')),
        );
        Navigator.of(context).pop();
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating data: $error')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // --------------------------------------------------------
  // Dispose
  // --------------------------------------------------------
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
        title: const Text('Update Equipment Definition'),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand
                    const Text('Select Brand *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                        return DropdownButtonFormField<String>(
                          value: selectedBrand,
                          items: brandList
                              .map(
                                (brand) => DropdownMenuItem(
                              value: brand,
                              child: Text(brand),
                            ),
                          )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedBrand = value;
                            });
                          },
                          validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Please select a brand'
                              : null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Equipment Type
                    const Text('Type of Equipment *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
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
                      onChanged: (value) {
                        setState(() {
                          selectedEquipmentType = value;
                        });
                      },
                      validator: (value) =>
                      (value == null || value.isEmpty)
                          ? 'Please select equipment type'
                          : null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Model
                    const Text('Model *',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        hintText: 'Enter model',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      (value == null || value.isEmpty)
                          ? 'Please enter the model'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Weight
                    const Text('Weight (kg)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        hintText: 'Enter weight in kg',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Dimensions row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dimension X (cm)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _dimensionXController,
                                decoration: const InputDecoration(
                                  hintText: 'X',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dimension Y (cm)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _dimensionYController,
                                decoration: const InputDecoration(
                                  hintText: 'Y',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Dimension Z (cm)',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _dimensionZController,
                                decoration: const InputDecoration(
                                  hintText: 'Z',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Power Capacity
                    const Text('Power Capacity (kW)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _powerCapacityController,
                      decoration: const InputDecoration(
                        hintText: 'Enter power capacity in kW',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Voltage
                    const Text('Voltage (V)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _voltageController,
                      decoration: const InputDecoration(
                        hintText: 'Enter voltage in V',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Equipment Image
                    const Text('Equipment Image (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _selectImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002244),
                          ),
                          child: const Text('Select Image'),
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

                    // Spare Parts
                    const Text('Spare Parts',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: spareParts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final sp = entry.value;
                        final name = sp['name'] ?? '';
                        final brand = sp['brand'] ?? '';
                        final model = sp['model'] ?? '';
                        final datasheetURL = sp['datasheetURL'] ?? '';
                        return ListTile(
                          title: Text('$name ($brand / $model)'),
                          subtitle: datasheetURL.isNotEmpty
                              ? Text('Datasheet: $datasheetURL')
                              : const Text('No datasheet'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await _showAddOrEditSparePartDialog(
                                  editIndex: index);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addSparePart,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add Spare Part'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Service Kits
                    const Text('Service Kits',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children:
                      serviceKits.asMap().entries.map((entry) {
                        final index = entry.key;
                        final kit = entry.value;
                        return ExpansionTile(
                          title: Text(kit['name'] ?? ''),
                          subtitle: (kit['globalDocument'] != null &&
                              (kit['globalDocument'] as String)
                                  .isNotEmpty)
                              ? Text('Global Document: ${kit['globalDocument']}')
                              : const Text('No Global Document'),
                          children: [
                            if (kit['items'] != null)
                              ...((kit['items'] as List).map((item) {
                                return ListTile(
                                  title: Text(item['name'] ?? ''),
                                  subtitle: Text(
                                      'Brand: ${item['brand']}, Model: ${item['model']}, Period: ${item['changePeriod']} h'),
                                );
                              }).toList()),
                          ],
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await _showAddOrEditServiceKitDialog(
                                  editIndex: index);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addServiceKit,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add Service Kit'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Equipment Documents
                    const Text('Equipment Documents',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: equipmentDocuments.asMap().entries
                          .map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        return ListTile(
                          title: Text(doc['docType'] ?? ''),
                          subtitle: Text(doc['fileName'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await _showAddOrEditEquipmentDocumentDialog(
                                  editIndex: index);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addEquipmentDocument,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add Equipment Document'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Equipment Definition Description
                    const Text('Equipment Definition Description',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter equipment definition description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Update Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateEquipmentDefinition,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002244),
                          padding:
                          const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Update Equipment Definition',
                            style: TextStyle(fontSize: 16)),
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
}
