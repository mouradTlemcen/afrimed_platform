import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
// For downloading images in PDF generation
import 'package:http/http.dart' as http;
// For launching URL to download final PPM
import 'package:url_launcher/url_launcher.dart';

class PreventiveMaintenanceProgressPage extends StatefulWidget {
  final String calendarId;       // Firestore doc ID of 'preventive_maintenance'
  final DateTime scheduledDate;

  const PreventiveMaintenanceProgressPage({
    Key? key,
    required this.calendarId,
    required this.scheduledDate,
  }) : super(key: key);

  @override
  _PreventiveMaintenanceProgressPageState createState() =>
      _PreventiveMaintenanceProgressPageState();
}

class _PreventiveMaintenanceProgressPageState
    extends State<PreventiveMaintenanceProgressPage> {
  // Equipment selection
  
  String? selectedEquipmentDocId;
  final Map<String, String> _eqDocIdToLabel = {}; // docId -> label
  List<String> equipmentRefOptions = [];

  // Data structure for service kits (grouped by kitName)
  List<Map<String, dynamic>> _serviceKitsData = [];

  bool isLoadingKitItems = false;
  bool isLoading = false; // for the main "Save" spinner

  final List<String> operationTypes = ["Checked", "Replaced", "Fixed", "Clean"];
  final TextEditingController _progressCommentController =
  TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // -- Ajout pour "All Equipment" :
  String _allEquipOperation = "Clean";           // ex. operation par défaut
  final TextEditingController _allEquipCommentCtrl = TextEditingController();
  XFile? _allEquipPickedImage;

  // For the final PPM report
  String? _finalPpmReportUrl;

  @override
  void initState() {
    super.initState();
    _fetchCalendarEquipmentList();
    _fetchFinalPpmReportUrl();
  }

  @override
  void dispose() {
    _progressCommentController.dispose();
    _allEquipCommentCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // 1) Load "equipmentList" from the 'preventive_maintenance' doc
  //    + Insérer l'option "ALL_EQUIP" pour All Equipment
  // ------------------------------------------------------------
  Future<void> _fetchCalendarEquipmentList() async {
    try {
      final pmDoc = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .get();
      if (!pmDoc.exists) return;

      final data = pmDoc.data() as Map<String, dynamic>? ?? {};
      final eqList = data['equipmentList'] as List<dynamic>? ?? [];

      for (var item in eqList) {
        if (item is Map<String, dynamic>) {
          final docId = item['docId'] as String?;
          final label = item['label'] as String?;
          if (docId != null && label != null) {
            _eqDocIdToLabel[docId] = label;
          }
        }
      }

      // On crée la liste des docIds, puis on insère "ALL_EQUIP" au début
      final options = _eqDocIdToLabel.keys.toList();
      options.insert(0, "ALL_EQUIP"); // <-- Option spéciale
      setState(() {
        equipmentRefOptions = options;
      });
    } catch (e) {
      debugPrint("Error fetching equipmentList: $e");
    }
  }

  // ------------------------------------------------------------
  // 2) Load final PPM report URL if any
  // ------------------------------------------------------------
  Future<void> _fetchFinalPpmReportUrl() async {
    try {
      final pmDoc = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .get();
      if (!pmDoc.exists) return;

      final data = pmDoc.data() as Map<String, dynamic>? ?? {};
      final url = data['finalPpmReportUrl'] as String?;
      setState(() {
        _finalPpmReportUrl = url;
      });
    } catch (e) {
      debugPrint("Error fetching finalPpmReportUrl: $e");
    }
  }

  // ------------------------------------------------------------
  // 3) Select an equipment => load from 'acquired_equipments'
  //    Si ALL_EQUIP => On ne charge rien
  // ------------------------------------------------------------
  Future<void> _onEquipmentSelected(String? eqDocId) async {
    if (eqDocId == null) {
      setState(() {
        selectedEquipmentDocId = null;
        _serviceKitsData.clear();
      });
      return;
    }

    setState(() {
      selectedEquipmentDocId = eqDocId;
      _serviceKitsData.clear();
      isLoadingKitItems = true;
    });

    // CAS SPECIAL: si on a choisi "ALL_EQUIP", on n'affiche pas d'items
    if (eqDocId == "ALL_EQUIP") {
      setState(() {
        isLoadingKitItems = false;
        _serviceKitsData.clear();
      });
      return;
    }

    // Sinon on charge les kits
    try {
      final eqRef = FirebaseFirestore.instance
          .collection('acquired_equipments')
          .doc(eqDocId);

      final eqSnap = await eqRef.get();
      if (!eqSnap.exists) {
        debugPrint("Doc $eqDocId not found in 'acquired_equipments'.");
        return;
      }

      final eqData = eqSnap.data() as Map<String, dynamic>? ?? {};
      final brand = eqData['brand']?.toString() ?? "";
      final model = eqData['model']?.toString() ?? "";

      final installedServiceKit =
      eqData['installedServiceKit'] as List<dynamic>?;

      if (installedServiceKit != null && installedServiceKit.isNotEmpty) {
        _buildUIFromInstalledKit(installedServiceKit);
      } else {
        // => fallback to equipment_definitions
        final defSnap = await FirebaseFirestore.instance
            .collection('equipment_definitions')
            .where('brand', isEqualTo: brand)
            .where('model', isEqualTo: model)
            .get();
        if (defSnap.docs.isEmpty) {
          debugPrint("No definitions for brand=$brand, model=$model");
          return;
        }

        final defData = defSnap.docs.first.data() as Map<String, dynamic>;
        final serviceKits = defData['serviceKits'] as List<dynamic>? ?? [];

        final newInstalledKit = <Map<String, dynamic>>[];
        for (var kit in serviceKits) {
          if (kit is Map<String, dynamic>) {
            final kitName = kit['name']?.toString() ?? "Unnamed Kit";
            final itemsArr = kit['items'] as List<dynamic>? ?? [];
            for (var item in itemsArr) {
              if (item is Map<String, dynamic>) {
                newInstalledKit.add({
                  'kitName': kitName,
                  'itemName': item['name']?.toString() ?? "Unnamed Item",
                  'brand': item['brand']?.toString() ?? "",
                  'model': item['model']?.toString() ?? "",
                  'serialNumber': item['serialNumber']?.toString() ?? "",
                });
              }
            }
          }
        }
        // => store newInstalledKit in acquired_equipments
        await eqRef.update({
          'installedServiceKit': newInstalledKit,
        });

        _buildUIFromInstalledKit(newInstalledKit);
      }
    } catch (e) {
      debugPrint("Error loading kit data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading kit data: $e")),
      );
    } finally {
      setState(() => isLoadingKitItems = false);
    }
  }

  // ------------------------------------------------------------
  // Build UI from a "flat" installedServiceKit array
  // ------------------------------------------------------------
  void _buildUIFromInstalledKit(List<dynamic> installedArray) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var entry in installedArray) {
      if (entry is Map<String, dynamic>) {
        final kitName = entry['kitName']?.toString() ?? "Unknown Kit";
        final itemName = entry['itemName']?.toString() ?? "Unnamed";
        final oldBrand = entry['brand']?.toString() ?? "";
        final oldModel = entry['model']?.toString() ?? "";
        final oldSerial = entry['serialNumber']?.toString() ?? "";

        if (!grouped.containsKey(kitName)) {
          grouped[kitName] = [];
        }
        grouped[kitName]!.add({
          'name': itemName,
          'checked': false,
          'operationType': operationTypes.first,
          'comment': '',
          'pickedImages': <Map<String, dynamic>>[], // Each map: { 'image': XFile, 'comment': String }


          // old => readOnly if non-empty
          'oldSerialNumber': oldSerial,
          'newSerialNumber': '',
          'oldBrand': oldBrand,
          'newBrand': '',
          'oldModel': oldModel,
          'newModel': '',
        });
      }
    }

    final newKitsData = <Map<String, dynamic>>[];
    for (var kName in grouped.keys) {
      newKitsData.add({
        'kitName': kName,
        'items': grouped[kName],
      });
    }

    setState(() {
      _serviceKitsData = newKitsData;
    });
  }

  // ------------------------------------------------------------
  // 4) Pick an image for a specific item
  // ------------------------------------------------------------
  Future<void> _pickItemImage(int kitIndex, int itemIndex) async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _serviceKitsData[kitIndex]['items'][itemIndex]['pickedImage'] = image;
        });
      }
    } catch (e) {
      debugPrint("Error picking item image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }
  // ------------------------------------------------------------
// 4b) Pick MULTIPLE images for a specific item
// ------------------------------------------------------------
  Future<void> _pickItemImages(int kitIndex, int itemIndex) async {
    try {
      final images = await _picker.pickMultiImage();
      if (images != null && images.isNotEmpty) {
        setState(() {
          // For each image, store a map: {'image': XFile, 'comment': ''}
          // Add new images to the existing list, don't replace it!
          final currentList = List<Map<String, dynamic>>.from(
            _serviceKitsData[kitIndex]['items'][itemIndex]['pickedImages'] ?? [],
          );
          final newImages = images.map((img) => {'image': img, 'comment': ''}).toList();
          currentList.addAll(newImages);
          _serviceKitsData[kitIndex]['items'][itemIndex]['pickedImages'] = currentList;

        });
      }
    } catch (e) {
      debugPrint("Error picking images: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking images: $e")),
      );
    }
  }


  /// Pick image "global" si All Equipment (optionnel)
  Future<void> _pickAllEquipImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _allEquipPickedImage = image;
        });
      }
    } catch (e) {
      debugPrint("Error picking image (All Equip): $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  // ------------------------------------------------------------
  // 5) Save progress
  //    - Si ALL_EQUIP => on enregistre UN SEUL item (All Equipment)
  //    - Sinon, on enregistre comme avant
  // ------------------------------------------------------------
  Future<void> _saveProgress() async {
    if (selectedEquipmentDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an equipment.")),
      );
      return;
    }

    // CAS ALL_EQUIP => On crée un serviceKitChangedItems avec un seul objet
    if (selectedEquipmentDocId == "ALL_EQUIP") {
      setState(() => isLoading = true);
      try {
        String? imageUrl;
        if (_allEquipPickedImage != null) {
          try {
            final itemName = "All_Equipment";
            final fileName =
                "${DateTime.now().millisecondsSinceEpoch}_$itemName";
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('progressItemImages')
                .child(fileName);

            UploadTask uploadTask;
            if (kIsWeb) {
              final bytes = await _allEquipPickedImage!.readAsBytes();
              uploadTask = storageRef.putData(bytes);
            } else {
              final localPath = _allEquipPickedImage!.path;
              uploadTask = storageRef.putFile(File(localPath));
            }
            final snapshot = await uploadTask;
            imageUrl = await snapshot.ref.getDownloadURL();
          } catch (e) {
            debugPrint("Error uploading image (All Equipment): $e");
          }
        }

        final changedItems = [
          {
            'kitName': "All Equipment",
            'itemName': "All Equipment",
            'operationType': _allEquipOperation,
            'comment': _allEquipCommentCtrl.text.trim(),
            'imageUrl': imageUrl ?? "",
            // pas de brand/model en mode global
            'oldSerialNumber': '',
            'newSerialNumber': '',
            'oldBrand': '',
            'newBrand': '',
            'oldModel': '',
            'newModel': '',
          }
        ];

        final progressDoc = {
          'scheduledDate': Timestamp.fromDate(widget.scheduledDate),
          'equipmentDocId': null, // ou "ALL_EQUIP"
          'equipmentLabel': "All Equipment", // pour l'affichage
          'overallProgressComment': _progressCommentController.text.trim(),
          'timestamp': Timestamp.now(),
          'serviceKitChangedItems': changedItems,
        };

        await FirebaseFirestore.instance
            .collection('preventive_maintenance')
            .doc(widget.calendarId)
            .collection('progress')
            .add(progressDoc);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Progress (All Equipment) saved successfully.")),
        );

        // reset
        _progressCommentController.clear();
        _allEquipCommentCtrl.clear();
        _allEquipPickedImage = null;
        _allEquipOperation = "Clean";
      } catch (e) {
        debugPrint("Error saving ALL_EQUIP progress: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving progress: $e")),
        );
      } finally {
        setState(() => isLoading = false);
      }
      return; // on sort
    }

    // Sinon: c'est un équipement normal => on enregistre "serviceKitChangedItems" etc.
    if (_serviceKitsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Service Kits available.")),
      );
      return;
    }

    setState(() => isLoading = true);

    final changedItems = <Map<String, dynamic>>[];
    final replacedItemsForUpdate = <Map<String, dynamic>>[];

    for (int k = 0; k < _serviceKitsData.length; k++) {
      final kitData = _serviceKitsData[k];
      final kitName = kitData['kitName'] as String;
      final items = kitData['items'] as List<dynamic>;

      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        if (item['checked'] == true) {
          final itemName = item['name'] ?? "Unknown";
          final opType = item['operationType'] ?? "N/A";
          final comment = item['comment'] ?? "";
          final pickedImages = item['pickedImages'] as List<dynamic>;

          final oldSn = item['oldSerialNumber'] ?? "";
          final newSn = item['newSerialNumber'] ?? "";
          var oldBrand = "";
          var newBrand = "";
          var oldModel = "";
          var newModel = "";

          if (opType == "Replaced") {
            oldBrand = item['oldBrand'] ?? "";
            newBrand = item['newBrand'] ?? "";
            oldModel = item['oldModel'] ?? "";
            newModel = item['newModel'] ?? "";
          }

          // -------- MULTI-IMAGE SUPPORT --------
          List<Map<String, dynamic>> imageEntries = [];
          for (final imgEntry in pickedImages) {
            final XFile? img = imgEntry['image'];
            final String imgComment = imgEntry['comment'] ?? '';
            String? imageUrl;
            if (img != null) {
              try {
                final fileName =
                    "${DateTime.now().millisecondsSinceEpoch}_${itemName}_${img.hashCode}";
                final storageRef = FirebaseStorage.instance
                    .ref()
                    .child('progressItemImages')
                    .child(fileName);

                UploadTask uploadTask;
                if (kIsWeb) {
                  final bytes = await img.readAsBytes();
                  uploadTask = storageRef.putData(bytes);
                } else {
                  final localPath = img.path;
                  uploadTask = storageRef.putFile(File(localPath));
                }

                final snapshot = await uploadTask;
                imageUrl = await snapshot.ref.getDownloadURL();
              } catch (e) {
                debugPrint("Error uploading image for item $itemName: $e");
              }
            }
            imageEntries.add({
              'imageUrl': imageUrl ?? "",
              'comment': imgComment,
            });
          }

          final itemMap = {
            'kitName': kitName,
            'itemName': itemName,
            'operationType': opType,
            'comment': comment,
            'images': imageEntries, // <---- Save ALL images with comments here!
            'oldSerialNumber': oldSn,
            'newSerialNumber': newSn,
            'oldBrand': oldBrand,
            'newBrand': newBrand,
            'oldModel': oldModel,
            'newModel': newModel,
          };
          changedItems.add(itemMap);

          if (opType == "Replaced") {
            try {
              await FirebaseFirestore.instance
                  .collection('brand_model_changes')
                  .add({
                'calendarId': widget.calendarId,
                'equipmentDocId': selectedEquipmentDocId,
                'timestamp': Timestamp.now(),
                'itemName': itemName,
                'oldBrand': oldBrand,
                'newBrand': newBrand,
                'oldModel': oldModel,
                'newModel': newModel,
              });
            } catch (e) {
              debugPrint("Error writing brand_model_changes: $e");
            }

            replacedItemsForUpdate.add({
              'kitName': kitName,
              'itemName': itemName,
              'brand': newBrand.isNotEmpty ? newBrand : oldBrand,
              'model': newModel.isNotEmpty ? newModel : oldModel,
              'serialNumber': newSn.isNotEmpty ? newSn : oldSn,
            });
          }
        }
      }
    }

    // Write main progress doc
    final progressData = {
      'scheduledDate': Timestamp.fromDate(widget.scheduledDate),
      'equipmentDocId': selectedEquipmentDocId,
      'equipmentLabel': _eqDocIdToLabel[selectedEquipmentDocId],
      'overallProgressComment': _progressCommentController.text.trim(),
      'timestamp': Timestamp.now(),
      'serviceKitChangedItems': changedItems,
    };

    try {
      await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .collection('progress')
          .add(progressData);

      // If we replaced items => update the acquired_equipments doc
      if (replacedItemsForUpdate.isNotEmpty) {
        await _updateAcquiredEquipAfterReplacement(replacedItemsForUpdate);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Progress saved successfully!")),
      );

      // Reset UI
      _progressCommentController.clear();
      setState(() {
        for (var kit in _serviceKitsData) {
          final items = kit['items'] as List<dynamic>;
          for (var item in items) {
            item['checked'] = false;
            item['operationType'] = operationTypes.first;
            item['comment'] = '';
            item['pickedImages'] = <Map<String, dynamic>>[]; // <-- Reset for multi-image!
            item['newSerialNumber'] = '';
            item['newBrand'] = '';
            item['newModel'] = '';
          }
        }
      });
    } catch (e) {
      debugPrint("Error saving progress: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving progress: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }


  // Mise à jour de brand/model/serial si items remplacés
  Future<void> _updateAcquiredEquipAfterReplacement(
      List<Map<String, dynamic>> replacedItems) async {
    if (selectedEquipmentDocId == null) return;

    try {
      final eqRef = FirebaseFirestore.instance
          .collection('acquired_equipments')
          .doc(selectedEquipmentDocId);
      final eqSnap = await eqRef.get();
      if (!eqSnap.exists) return;

      final eqData = eqSnap.data() as Map<String, dynamic>? ?? {};
      final installedKit = eqData['installedServiceKit'] as List<dynamic>? ?? [];

      for (final rep in replacedItems) {
        final kitName = rep['kitName'] ?? "";
        final itemName = rep['itemName'] ?? "";
        final newBrand = rep['brand'] ?? "";
        final newModel = rep['model'] ?? "";
        final newSerial = rep['serialNumber'] ?? "";

        for (int i = 0; i < installedKit.length; i++) {
          final entry = installedKit[i];
          if (entry is Map<String, dynamic>) {
            if (entry['kitName'] == kitName && entry['itemName'] == itemName) {
              installedKit[i]['brand'] = newBrand;
              installedKit[i]['model'] = newModel;
              installedKit[i]['serialNumber'] = newSerial;
              break;
            }
          }
        }
      }

      await eqRef.update({
        'installedServiceKit': installedKit,
      });
    } catch (e) {
      debugPrint("Error updating acquired eq doc after replacement: $e");
    }
  }

  // ------------------------------------------------------------
  // 6) Upload a Final PPM Report
  // ------------------------------------------------------------
  Future<void> _pickAndUploadFinalPpmReport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;
        final fileName =
            "${DateTime.now().millisecondsSinceEpoch}_final_ppm_report.pdf";

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('finalPpmReports')
            .child(fileName);

        UploadTask uploadTask;
        if (kIsWeb) {
          final uploadData = pickedFile.bytes!;
          uploadTask = storageRef.putData(uploadData);
        } else {
          final localPath = pickedFile.path!;
          uploadTask = storageRef.putFile(File(localPath));
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('preventive_maintenance')
            .doc(widget.calendarId)
            .update({'finalPpmReportUrl': downloadUrl});

        setState(() {
          _finalPpmReportUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Final PPM report uploaded successfully.")),
        );
      }
    } catch (e) {
      debugPrint("Error picking/uploading final Ppm report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ------------------------------------------------------------
  // 7) Download final PPM if it exists
  // ------------------------------------------------------------
  Future<void> _downloadFinalPpmReport() async {
    if (_finalPpmReportUrl == null || _finalPpmReportUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No final report URL available.")),
      );
      return;
    }
    final Uri url = Uri.parse(_finalPpmReportUrl!);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch final report URL.")),
      );
    }
  }

  // ------------------------------------------------------------
  // 8) Generate and download a PDF of all progress
  // ------------------------------------------------------------
  Future<void> _generateAndDownloadAllProgressAsPdf() async {
    try {
      final progressSnap = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .collection('progress')
          .orderBy('timestamp', descending: false)
          .get();
      final docs = progressSnap.docs;
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No progress found to export.")),
        );
        return;
      }

      final progressDataList = <Map<String, dynamic>>[];
      for (final doc in docs) {
        final data = doc.data();
        final items = data['serviceKitChangedItems'] as List<dynamic>? ?? [];
        // fetch images
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            final images = item['images'] as List<dynamic>? ?? [];
            final List<Map<String, dynamic>> imageBytesList = [];
            for (final imgMap in images) {
              final imageUrl = imgMap['imageUrl'] ?? '';
              final comment = imgMap['comment'] ?? '';
              Uint8List? imageBytes;
              if (imageUrl.isNotEmpty) {
                try {
                  final response = await http.get(Uri.parse(imageUrl));
                  if (response.statusCode == 200) {
                    imageBytes = response.bodyBytes;
                  }
                } catch (e) {
                  debugPrint("Error fetching image from $imageUrl: $e");
                }
              }
              imageBytesList.add({
                'imageBytes': imageBytes,
                'comment': comment,
              });
            }
            item['imageBytesList'] = imageBytesList;

          }
        }
        progressDataList.add(data);
      }

      final pdf = pw.Document();
      final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  "Preventive Maintenance Progress Report",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              ...progressDataList.map((data) {
                final ts = data['timestamp'] as Timestamp?;
                final dateStr = (ts != null)
                    ? dateFormatter.format(ts.toDate())
                    : "N/A";
                final eqLabel = data['equipmentLabel'] ?? "Unknown Equipment";
                final overallComment = data['overallProgressComment'] ?? "";
                final items =
                    data['serviceKitChangedItems'] as List<dynamic>? ?? [];

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Date: $dateStr",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Equipment: $eqLabel"),
                    pw.Text("Overall Comment: $overallComment"),
                    pw.SizedBox(height: 5),
                    pw.Text("Changed Items:",
                        style: pw.TextStyle(
                            decoration: pw.TextDecoration.underline)),
                    if (items.isEmpty)
                      pw.Text("  - No items changed.")
                    else
                      pw.Column(
                        children: items.map((itemData) {
                          if (itemData is Map<String, dynamic>) {
                            final itemName = itemData['itemName'] ?? "Unknown";
                            final opType = itemData['operationType'] ?? "N/A";
                            final comment = itemData['comment'] ?? "";
                            final oldSn = itemData['oldSerialNumber'] ?? "";
                            final newSn = itemData['newSerialNumber'] ?? "";
                            final oldBrand = itemData['oldBrand'] ?? "";
                            final newBrand = itemData['newBrand'] ?? "";
                            final oldModel = itemData['oldModel'] ?? "";
                            final newModel = itemData['newModel'] ?? "";

                            // Get all images (with bytes and comments)
                            final List imageBytesList = itemData['imageBytesList'] ?? [];

                            return pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  "  - $itemName ($opType)\n     Comment: $comment",
                                ),
                                if (oldSn.isNotEmpty || newSn.isNotEmpty)
                                  pw.Text("     Old SN: $oldSn | New SN: $newSn"),
                                if (opType == "Replaced")
                                  pw.Text(
                                    "     Old Brand: $oldBrand => New Brand: $newBrand\n"
                                        "     Old Model: $oldModel => New Model: $newModel",
                                  ),
                                // Show all images and their comments
                                if (imageBytesList.isNotEmpty) ...[
                                  pw.SizedBox(height: 8),
                                  ...imageBytesList.map<pw.Widget>((img) {
                                    final imageBytes = img['imageBytes'] as Uint8List?;
                                    final imgComment = img['comment'] ?? '';
                                    if (imageBytes == null) return pw.SizedBox();
                                    return pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Image(
                                          pw.MemoryImage(imageBytes),
                                          width: 200,
                                          height: 200,
                                          fit: pw.BoxFit.cover,
                                        ),
                                        if (imgComment.isNotEmpty)
                                          pw.Text("Comment: $imgComment", style: pw.TextStyle(fontSize: 10)),
                                        pw.SizedBox(height: 6),
                                      ],
                                    );
                                  }).toList(),
                                ],
                                pw.SizedBox(height: 10),
                              ],
                            );
                          }

                          return pw.SizedBox();
                        }).toList(),
                      ),
                    pw.Divider(height: 30),
                  ],
                );
              }).toList(),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      debugPrint("Error generating/downloading PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating PDF: $e")),
      );
    }
  }

  // ------------------------------------------------------------
  // 9) Delete a progress doc => Only if it's the newest => revert replaced items
  // ------------------------------------------------------------
  Future<void> _deleteProgressDoc(String docId) async {
    final progressColl = FirebaseFirestore.instance
        .collection('preventive_maintenance')
        .doc(widget.calendarId)
        .collection('progress');

    try {
      // 1) Check if docId is the newest doc
      final newestSnap = await progressColl
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (newestSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No progress documents to delete.")),
        );
        return;
      }
      if (newestSnap.docs.first.id != docId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can only delete the last progress.")),
        );
        return;
      }

      // 2) read doc data
      final docSnap = await progressColl.doc(docId).get();
      if (!docSnap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Progress doc not found.")),
        );
        return;
      }
      final data = docSnap.data() as Map<String, dynamic>;
      final changedItems =
          data['serviceKitChangedItems'] as List<dynamic>? ?? [];

      // 3) For replaced items => revert brand/model/serial to 'oldBrand/oldModel/oldSerialNumber'
      final itemsToRevert = <Map<String, dynamic>>[];
      for (final ci in changedItems) {
        if (ci is Map<String, dynamic>) {
          final opType = ci['operationType'] ?? "";
          if (opType == "Replaced") {
            final kitName = ci['kitName'] ?? "";
            final itemName = ci['itemName'] ?? "";
            final oldBrand = ci['oldBrand'] ?? "";
            final oldModel = ci['oldModel'] ?? "";
            final oldSn = ci['oldSerialNumber'] ?? "";
            itemsToRevert.add({
              'kitName': kitName,
              'itemName': itemName,
              'brand': oldBrand,
              'model': oldModel,
              'serialNumber': oldSn,
            });
          }
        }
      }

      if (itemsToRevert.isNotEmpty && selectedEquipmentDocId != null) {
        await _revertAcquiredEquipItems(itemsToRevert, selectedEquipmentDocId!);
      }

      // 4) delete doc
      await progressColl.doc(docId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Progress deleted & old brand/model restored.")),
      );
    } catch (e) {
      debugPrint("Error deleting progress: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting progress: $e")),
      );
    }
  }

  /// Helper to revert brand/model/serial for each replaced item
  /// using the "old" fields from that doc
  Future<void> _revertAcquiredEquipItems(
      List<Map<String, dynamic>> itemsToRevert, String eqDocId) async {
    try {
      final eqRef = FirebaseFirestore.instance
          .collection('acquired_equipments')
          .doc(eqDocId);
      final eqSnap = await eqRef.get();
      if (!eqSnap.exists) return;

      final eqData = eqSnap.data() as Map<String, dynamic>? ?? {};
      final installedKit = eqData['installedServiceKit'] as List<dynamic>? ?? [];

      for (final revertData in itemsToRevert) {
        final kitName = revertData['kitName'] ?? "";
        final itemName = revertData['itemName'] ?? "";
        final brand = revertData['brand'] ?? "";
        final model = revertData['model'] ?? "";
        final serial = revertData['serialNumber'] ?? "";

        // find matching entry in installedKit and revert
        for (int i = 0; i < installedKit.length; i++) {
          final entry = installedKit[i];
          if (entry is Map<String, dynamic>) {
            if (entry['kitName'] == kitName && entry['itemName'] == itemName) {
              installedKit[i]['brand'] = brand;
              installedKit[i]['model'] = model;
              installedKit[i]['serialNumber'] = serial;
              break;
            }
          }
        }
      }

      await eqRef.update({
        'installedServiceKit': installedKit,
      });
    } catch (e) {
      debugPrint("Error reverting old brand/model/serial: $e");
    }
  }

  // ------------------------------------------------------------
  // 10) Build a list of existing progress docs
  // ------------------------------------------------------------
  Widget _buildProgressUpdatesList() {
    DateTime scheduledDay =
    DateTime(widget.scheduledDate.year, widget.scheduledDate.month, widget.scheduledDate.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .collection('progress')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(scheduledDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(scheduledDay.add(const Duration(days: 1))))
          .orderBy('scheduledDate', descending: true)
          .snapshots(),
      builder: (context, snap) {
        // ... your existing builder logic here ...
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text("No progress updates yet for this date."));
        }

        final docs = snap.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docSnap = docs[index];
            final data = docSnap.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            final dateStr = (ts != null)
                ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                : "N/A";

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                title: Text("Update at $dateStr"),
                subtitle: Text(
                  "Items changed: "
                      "${(data['serviceKitChangedItems'] as List<dynamic>? ?? []).length}",
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PreventiveMaintenanceProgressDetailPage(
                        progressData: data,
                      ),
                    ),
                  );
                },
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProgressDoc(docSnap.id),
                ),
              ),
            );
          },
        );
      },
    );
  }


  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.scheduledDate);

    return Scaffold(
      appBar: AppBar(
        title: Text("Progress for $dateStr"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Equipment selection (incl. "ALL_EQUIP")
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Select Equipment",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      value: selectedEquipmentDocId,
                      items: equipmentRefOptions.map((docId) {
                        // Si c'est "ALL_EQUIP", on affiche "All Equipment" comme label
                        if (docId == "ALL_EQUIP") {
                          return const DropdownMenuItem(
                            value: "ALL_EQUIP",
                            child: Text("All Equipment"),
                          );
                        }
                        // Sinon on prend le label normal
                        final label = _eqDocIdToLabel[docId] ?? docId;
                        return DropdownMenuItem(
                          value: docId,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: _onEquipmentSelected,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Si on a choisi ALL_EQUIP, afficher un bloc d'opération globale
            if (selectedEquipmentDocId == "ALL_EQUIP")
              Card(
                elevation: 6,
                shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "All Equipment (global operation):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      // Operation type
                      DropdownButtonFormField<String>(
                        value: _allEquipOperation,
                        decoration: const InputDecoration(
                          labelText: "Operation Type",
                          border: OutlineInputBorder(),
                        ),
                        items: operationTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _allEquipOperation = val ?? "Clean";
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Commentaire global (spécifique AllEquip)
                      TextFormField(
                        controller: _allEquipCommentCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "All Equip Comment",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Bouton pour image
                      ElevatedButton.icon(
                        onPressed: _pickAllEquipImage,
                        icon: const Icon(Icons.add_a_photo),
                        label: const Text("Add Picture (optional)"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                      if (_allEquipPickedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey),
                              image: DecorationImage(
                                image: kIsWeb
                                    ? NetworkImage(_allEquipPickedImage!.path)
                                    : FileImage(
                                  File(_allEquipPickedImage!.path),
                                ) as ImageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )

            // Sinon on affiche la liste des Service Kits
            else if (selectedEquipmentDocId != null)
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: isLoadingKitItems
                      ? const Center(child: CircularProgressIndicator())
                      : _serviceKitsData.isEmpty
                      ? const Text("No Service Kits available.")
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Service Kit Items",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._serviceKitsData.asMap().entries.map((kitEntry) {
                        final kitIndex = kitEntry.key;
                        final kit = kitEntry.value;
                        final kitName = kit['kitName'] as String;
                        final items = kit['items'] as List<dynamic>;

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              kitName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...items.asMap().entries.map((itemEntry) {
                              final itemIndex = itemEntry.key;
                              final item = itemEntry.value
                              as Map<String, dynamic>;

                              final itemName = item['name'] as String;
                              final checked = item['checked'] as bool;
                              final opType =
                              item['operationType'] as String;
                              final comment = item['comment'] as String;
                              final XFile? pickedImage =
                              item['pickedImage'];

                              final oldSn =
                              item['oldSerialNumber'] as String;
                              final newSn =
                              item['newSerialNumber'] as String;
                              final oldBrand =
                              item['oldBrand'] as String;
                              final newBrand =
                              item['newBrand'] as String;
                              final oldModel =
                              item['oldModel'] as String;
                              final newModel =
                              item['newModel'] as String;

                              return Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    title: Text(itemName),
                                    value: checked,
                                    onChanged: (bool? val) {
                                      setState(() {
                                        item['checked'] = val ?? false;
                                      });
                                    },
                                  ),
                                  if (checked) ...[
                                    // Operation type
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(left: 40),
                                      child:
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        decoration:
                                        const InputDecoration(
                                          labelText: "Operation Type",
                                          border: OutlineInputBorder(),
                                        ),
                                        value: opType,
                                        items: operationTypes.map((type) {
                                          return DropdownMenuItem(
                                            value: type,
                                            child: Text(type),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            item['operationType'] = value;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Comment
                                    Padding(
                                      padding:
                                      const EdgeInsets.only(left: 40),
                                      child: TextFormField(
                                        initialValue: comment,
                                        decoration:
                                        const InputDecoration(
                                          labelText: "Item Comment",
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (val) {
                                          item['comment'] = val;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // If replaced => brand/model/serial
                                    if (opType == "Replaced") ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: oldSn,
                                          readOnly: oldSn.isNotEmpty,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "Old Serial Number",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            if (oldSn.isEmpty) {
                                              item['oldSerialNumber'] =
                                                  val;
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: newSn,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "New Serial Number",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            item['newSerialNumber'] =
                                                val;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Old Brand
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: oldBrand,
                                          readOnly: oldBrand.isNotEmpty,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "Old Brand",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            if (oldBrand.isEmpty) {
                                              item['oldBrand'] = val;
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // New Brand
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: newBrand,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "New Brand",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            item['newBrand'] = val;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Old Model
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: oldModel,
                                          readOnly: oldModel.isNotEmpty,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "Old Model",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            if (oldModel.isEmpty) {
                                              item['oldModel'] = val;
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // New Model
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: TextFormField(
                                          initialValue: newModel,
                                          decoration:
                                          const InputDecoration(
                                            labelText: "New Model",
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (val) {
                                            item['newModel'] = val;
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    // Image pick button
                                    Padding(
                                      padding: const EdgeInsets.only(left: 40),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () => _pickItemImages(kitIndex, itemIndex),
                                            icon: const Icon(Icons.add_a_photo),
                                            label: const Text("Add Pictures"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                            ),
                                          ),
                                          Builder(
                                            builder: (context) {
                                              final pickedImages = item['pickedImages'] as List<dynamic>;
                                              if (pickedImages.isEmpty) return SizedBox();
                                              return Padding(
                                                padding: const EdgeInsets.only(top: 6),
                                                child: Wrap(
                                                  spacing: 10,
                                                  runSpacing: 10,
                                                  children: pickedImages.map<Widget>((imgMap) {
                                                    final XFile? xfile = imgMap['image'];
                                                    final String comment = imgMap['comment'] ?? '';
                                                    return Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          width: 80,
                                                          height: 80,
                                                          decoration: BoxDecoration(
                                                            border: Border.all(color: Colors.grey),
                                                            borderRadius: BorderRadius.circular(8),
                                                            image: xfile == null
                                                                ? null
                                                                : DecorationImage(
                                                              image: kIsWeb
                                                                  ? NetworkImage(xfile.path)
                                                                  : FileImage(File(xfile.path))
                                                              as ImageProvider,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        ),
                                                        SizedBox(height: 5),
                                                        SizedBox(
                                                          width: 80,
                                                          child: TextFormField(
                                                            initialValue: comment,
                                                            decoration: InputDecoration(
                                                              hintText: "Comment",
                                                              contentPadding: EdgeInsets.symmetric(
                                                                  vertical: 4, horizontal: 6),
                                                              border: OutlineInputBorder(),
                                                            ),
                                                            onChanged: (val) {
                                                              setState(() {
                                                                imgMap['comment'] = val;
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }).toList(),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (pickedImage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40),
                                        child: Container(
                                          margin: const EdgeInsets
                                              .symmetric(vertical: 8),
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(8),
                                            border: Border.all(
                                                color: Colors.grey),
                                            image: DecorationImage(
                                              image: kIsWeb
                                                  ? NetworkImage(
                                                  pickedImage.path)
                                                  : FileImage(File(
                                                  pickedImage.path))
                                              as ImageProvider,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                  const SizedBox(height: 20),
                                ],
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Overall comment (toujours affiché, pour un commentaire global)
            Card(
              elevation: 6,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _progressCommentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "Overall Progress Comment (optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Boutons "Save", "Upload Final", etc.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : _saveProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Progress"),
                ),
                ElevatedButton.icon(
                  onPressed: _pickAndUploadFinalPpmReport,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Upload Final PPM Report"),
                ),
                ElevatedButton.icon(
                  onPressed: _generateAndDownloadAllProgressAsPdf,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.download),
                  label: const Text("Download All Progresses in a PDF file"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_finalPpmReportUrl != null && _finalPpmReportUrl!.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _downloadFinalPpmReport,
                  icon: const Icon(Icons.download),
                  label: const Text("Download Final PPM Report"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),

            const SizedBox(height: 16),

            const Text(
              "Progress Updates",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // The list of progress updates, no fixed height, let it grow
            _buildProgressUpdatesList(),
          ],
        ),
      ),
    );
  }
}

/// Detailed page for a single progress doc
class PreventiveMaintenanceProgressDetailPage extends StatelessWidget {
  final Map<String, dynamic> progressData;

  const PreventiveMaintenanceProgressDetailPage({
    Key? key,
    required this.progressData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ts = progressData['timestamp'] as Timestamp?;
    final dateStr = (ts != null)
        ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
        : "N/A";

    final overallComment = progressData['overallProgressComment'] ?? "";
    final changedItems =
        progressData['serviceKitChangedItems'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Details"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Updated on: $dateStr",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text("Overall Comment: "
                    "${overallComment.isEmpty ? 'None' : overallComment}"),
                const Divider(height: 24),
                const Text("Changed Items:",
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                if (changedItems.isEmpty)
                  const Text("No items changed.")
                else
                  Column(
                    children: changedItems.map((itemData) {
                      if (itemData is Map<String, dynamic>) {
                        final itemName = itemData['itemName'] ?? "unknown";
                        final opType = itemData['operationType'] ?? "N/A";
                        final comment = itemData['comment'] ?? "";
                        final oldSn = itemData['oldSerialNumber'] ?? "";
                        final newSn = itemData['newSerialNumber'] ?? "";
                        final oldBrand = itemData['oldBrand'] ?? "";
                        final newBrand = itemData['newBrand'] ?? "";
                        final oldModel = itemData['oldModel'] ?? "";
                        final newModel = itemData['newModel'] ?? "";

                        // Here is the change: get the images list
                        final List images = itemData['images'] ?? [];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Item: $itemName",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text("Operation: $opType"),
                              if (comment.isNotEmpty) Text("Comment: $comment"),
                              if (oldSn.isNotEmpty || newSn.isNotEmpty)
                                Text("Old SN: $oldSn | New SN: $newSn"),
                              if (opType == "Replaced") ...[
                                Text("Old Brand: $oldBrand => New Brand: $newBrand"),
                                Text("Old Model: $oldModel => New Model: $newModel"),
                              ],
                              // ---- Show all images with their comment ----
                              if (images.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: images.map<Widget>((imgMap) {
                                    final imgUrl = imgMap['imageUrl'] ?? '';
                                    final imgComment = imgMap['comment'] ?? '';
                                    if (imgUrl.isEmpty) return SizedBox.shrink();
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey),
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: NetworkImage(imgUrl),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        if (imgComment.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: SizedBox(
                                              width: 90,
                                              child: Text(
                                                imgComment,
                                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
