import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For file uploads.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For current user.

/// Wraps an image file with a comment controller.
class DiagnosticPicture {
  final XFile file;
  final TextEditingController commentController;
  DiagnosticPicture({required this.file})
      : commentController = TextEditingController();
}

class CreateCurativeTicketPage extends StatefulWidget {
  const CreateCurativeTicketPage({Key? key}) : super(key: key);

  @override
  _CreateCurativeTicketPageState createState() =>
      _CreateCurativeTicketPageState();
}

class _CreateCurativeTicketPageState extends State<CreateCurativeTicketPage> {
  final _formKey = GlobalKey<FormState>();

  // ---------- Project / Site / PSA Variables ----------
  List<Map<String, dynamic>> projectList = [];
  List<Map<String, dynamic>> siteList = [];
  List<Map<String, dynamic>> psaList = [];
  List<Map<String, dynamic>> equipmentList = [];

  // ---------- Spare parts ----------
  List<Map<String, dynamic>> sparePartsList = [];
  String? selectedSparePart;
  bool fixSparePart = false;
  bool replaceSparePart = false;

  // ---------- Service Kits ----------
  List<Map<String, dynamic>> serviceKitList = [];
  int? selectedServiceKitIndex; // -1 = no kit
  List<Map<String, dynamic>> selectedKitItems = [];
  Map<String, bool> selectedKitItemsMap = {};
  bool fixServiceKit = false;
  bool replaceServiceKit = false;

  // ---------- Project & PSA info ----------
  String? selectedProjectDocId;
  String? selectedProjectField;
  String? selectedSiteId;
  String? selectedSiteName;
  String? selectedPSAId;
  String? selectedPSAReference;
  Map<String, String> lineReferences = {};
  String? selectedLine;

  // ---------- Equipment ----------
  String? selectedEquipmentId;
  String? selectedEquipmentName;
  String? selectedEquipmentBrand;
  String? selectedEquipmentModel;

  // ---------- Local Operator (Hospital) ----------
  List<Map<String, String>> localOperatorList = [];
  String? selectedLocalOperator;

  // ---------- Incident Section (Title only now) ----------
  final TextEditingController ticketTitleController = TextEditingController();
  final TextEditingController ticketCreatedByController =
  TextEditingController();

  // ---------- Follow-up users ----------
  List<Map<String, String>> followUpUserList = [];
  String? selectedFollowUpUser1;
  String? selectedFollowUpUser2;

  // ---------- Diagnostic pictures ----------
  List<DiagnosticPicture> _diagnosticPictures = [];

  // ---------- Optional report file ----------
  PlatformFile? _reportFile;

  // ---------- Incident / maintenance stats ----------
  DateTime? incidentDateTime;
  DateTime? estimatedEndingDate;
  bool equipmentStopped = false;
  bool psaStopped = false;
  bool underWarranty = false;

  late Future<void> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _fetchProjects();
    _fetchLocalOperators();
    _fetchFollowUpUsers();

    // Pre-fill the "ticketCreatedBy" from the current user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      ticketCreatedByController.text = user.displayName ?? user.email ?? "";
    }
  }

  // ============================== FIRESTORE FETCHES ==============================

  Future<void> _fetchProjects() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('projects').get();
      final List<Map<String, dynamic>> temp = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          "docId": doc.id, // Firestore doc ID
          "projectField": data["Afrimed_projectId"] ?? "Unknown",
        };
      }).toList();
      setState(() {
        projectList = temp;
      });
      debugPrint(
          ">> _fetchProjects: Retrieved ${projectList.length} project(s).");
    } catch (e) {
      debugPrint(">> _fetchProjects ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching projects: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchSites(String projectDocId) async {
    debugPrint(">> _fetchSites(projectDocId: $projectDocId)");
    try {
      final lotSnap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDocId)
          .collection('lots')
          .get();
      List<Map<String, dynamic>> allSites = [];
      for (var lotDoc in lotSnap.docs) {
        final siteSnap = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectDocId)
            .collection('lots')
            .doc(lotDoc.id)
            .collection('sites')
            .get();
        for (var s in siteSnap.docs) {
          final sData = s.data() as Map<String, dynamic>;
          debugPrint(
              ">> Found site doc with id: ${s.id}, siteName: ${sData["siteName"]}");
          allSites.add({
            "id": s.id,
            "siteName": sData["siteName"] ?? "Unnamed Site",
          });
        }
      }
      debugPrint(">> _fetchSites: Found ${allSites.length} site(s).");
      setState(() {
        siteList = allSites;
      });
    } catch (e) {
      debugPrint(">> _fetchSites ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching sites: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchPSA(String projectField, String siteId) async {
    debugPrint(
        ">> _fetchPSA called with Afrimed_projectId=$projectField, siteId=$siteId");
    try {
      debugPrint(
          ">> Querying PSA with Afrimed_projectId: '$projectField' and siteId: '$siteId'");
      final snap = await FirebaseFirestore.instance
          .collection('psa_units')
          .where('Afrimed_projectId', isEqualTo: projectField)
          .where('siteId', isEqualTo: siteId)
          .get();
      debugPrint(">> _fetchPSA: Found ${snap.docs.length} doc(s).");
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No PSA found for the chosen project & site."),
          backgroundColor: Colors.orange,
        ));
        setState(() {
          psaList.clear();
          selectedPSAReference = null;
          selectedPSAId = null;
        });
        return;
      }
      setState(() {
        psaList = snap.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          debugPrint(">> PSA doc ${doc.id} => $data");
          return {
            "id": doc.id,
            "reference": data["reference"] ?? "Unknown",
            "lineReferences": data["lineReferences"],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint(">> _fetchPSA ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching PSA documents: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _fetchEquipment(String psaRef, String lineKey) async {
    if (selectedPSAId == null) return;
    final processedLineKey = lineKey.toLowerCase().replaceAll(" ", "");
    debugPrint(
        ">> _fetchEquipment: for psaRef=$psaRef, docId=$selectedPSAId, lineKey=$lineKey => $processedLineKey");
    try {
      final psaEquipSnapshot = await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(selectedPSAId)
          .collection('PSA_linked_equipment_list')
          .get();
      debugPrint(
          ">> _fetchEquipment: Found ${psaEquipSnapshot.docs.length} doc(s).");
      final List<Map<String, dynamic>> newEquipList = [];
      for (var doc in psaEquipSnapshot.docs) {
        if (doc.id.startsWith(processedLineKey)) {
          final dData = doc.data();
          final equipId = dData["equipmentId"]?.toString() ?? "";
          if (equipId.isNotEmpty && equipId != "Not Concerned") {
            final equipDocSnapshot = await FirebaseFirestore.instance
                .collection('acquired_equipments')
                .doc(equipId)
                .get();
            if (equipDocSnapshot.exists) {
              final equipData =
              equipDocSnapshot.data() as Map<String, dynamic>;
              final brand = equipData["brand"]?.toString() ?? "No Brand";
              final model = equipData["model"]?.toString() ?? "No Model";
              final serial =
                  equipData["serialNumber"]?.toString() ?? "No Serial";
              final fullEquipReference = "$brand / $model / $serial".trim();
              newEquipList.add({
                "id": equipId,
                "name": fullEquipReference,
                "brand": brand,
                "model": model,
              });
            }
          }
        }
      }
      debugPrint(
          ">> _fetchEquipment: Filtered ${newEquipList.length} match(es).");
      setState(() {
        equipmentList = newEquipList;
      });
      if (newEquipList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No equipment found for the selected line."),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e, stack) {
      debugPrint(">> _fetchEquipment ERROR: $e\n$stack");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching equipment: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ============ SPARE PARTS FETCH ============
  Future<void> _fetchSparePartsByBrandModel(String brand, String model) async {
    if (brand.trim().isEmpty || model.trim().isEmpty) {
      debugPrint(">> _fetchSparePartsByBrandModel: brand/model empty.");
      setState(() {
        sparePartsList = [];
        selectedSparePart = "No spare part";
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Cannot fetch spare parts: brand or model missing."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    debugPrint(">> _fetchSparePartsByBrandModel: brand='$brand', model='$model'");
    try {
      final eqDefSnap = await FirebaseFirestore.instance
          .collection('equipment_definitions')
          .where('brand', isEqualTo: brand)
          .where('model', isEqualTo: model)
          .get();

      if (eqDefSnap.docs.isEmpty) {
        debugPrint(
            ">> No equipment definition found for brand='$brand' & model='$model'.");
        setState(() {
          sparePartsList = [];
          selectedSparePart = "No spare part";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No equipment definition found for $brand / $model"),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final eqDefDoc = eqDefSnap.docs.first;
      debugPrint(
          ">> Found eq definition docId=${eqDefDoc.id} for brand=$brand model=$model");
      final data = eqDefDoc.data() as Map<String, dynamic>;
      final sparePartsField = data["spareParts"];
      if (sparePartsField == null || sparePartsField is! List) {
        debugPrint(">> No spareParts list found in doc ${eqDefDoc.id}");
        setState(() {
          sparePartsList = [];
          selectedSparePart = "No spare part";
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No spare parts available for $brand / $model"),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      // Build the list
      final List<Map<String, dynamic>> loadedSpareParts = [];
      for (var item in sparePartsField) {
        if (item is Map<String, dynamic>) {
          final spareName = item["name"]?.toString() ?? "Unnamed Spare";
          final spareBrand = item["brand"]?.toString() ?? "No Brand";
          final displayString = "$spareBrand / $spareName";
          loadedSpareParts.add({
            "id": "",
            "name": displayString,
          });
          debugPrint(">> Found spare part => $displayString");
        } else {
          debugPrint(
              ">> Unexpected item type in spareParts: ${item.runtimeType}");
        }
      }

      setState(() {
        sparePartsList = loadedSpareParts;
        if (loadedSpareParts.isEmpty) {
          // If none found, force "No spare part"
          selectedSparePart = "No spare part";
        } else {
          // Even if some are found, you can default to "No spare part"
          selectedSparePart = "No spare part";
        }
      });

      debugPrint(
          ">> _fetchSparePartsByBrandModel: Loaded ${loadedSpareParts.length} spare part(s).");
    } catch (e, stack) {
      debugPrint(">> _fetchSparePartsByBrandModel ERROR: $e\n$stack");
      setState(() {
        sparePartsList = [];
        selectedSparePart = "No spare part";
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching spare parts for $brand / $model: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ============ SERVICE KITS FETCH ============
  Future<void> _fetchServiceKitsByBrandModel(String brand, String model) async {
    if (brand.trim().isEmpty || model.trim().isEmpty) {
      debugPrint(">> _fetchServiceKitsByBrandModel: brand/model empty.");
      setState(() {
        serviceKitList = [];
        selectedServiceKitIndex = -1;
        selectedKitItems.clear();
        selectedKitItemsMap.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Cannot fetch service kits: brand or model missing."),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    debugPrint(">> _fetchServiceKitsByBrandModel: brand=$brand model=$model");
    try {
      final eqDefSnap = await FirebaseFirestore.instance
          .collection('equipment_definitions')
          .where('brand', isEqualTo: brand)
          .where('model', isEqualTo: model)
          .get();

      if (eqDefSnap.docs.isEmpty) {
        debugPrint(
            ">> No eq definition found for brand='$brand' & model='$model'.");
        setState(() {
          serviceKitList = [];
          selectedServiceKitIndex = -1;
          selectedKitItems.clear();
          selectedKitItemsMap.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No equipment definition found for $brand / $model"),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final eqDefDoc = eqDefSnap.docs.first;
      debugPrint(
          ">> Found eq definition docId=${eqDefDoc.id} for brand=$brand model=$model");
      final data = eqDefDoc.data() as Map<String, dynamic>;
      final serviceKitsField = data["serviceKits"];
      if (serviceKitsField == null || serviceKitsField is! List) {
        debugPrint(">> No 'serviceKits' list found in doc ${eqDefDoc.id}");
        setState(() {
          serviceKitList = [];
          selectedServiceKitIndex = -1;
          selectedKitItems.clear();
          selectedKitItemsMap.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No service kits available for $brand / $model"),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final List<Map<String, dynamic>> loadedKits = [];
      for (int i = 0; i < serviceKitsField.length; i++) {
        final kit = serviceKitsField[i];
        if (kit is Map<String, dynamic>) {
          final kitItems = kit["items"] ?? [];
          final kitName = _determineKitDisplayName(kit, i);
          loadedKits.add({
            "id": i,
            "name": kitName,
            "items": kitItems,
          });
        } else {
          debugPrint(">> Unexpected kit type: ${kit.runtimeType}");
        }
      }

      setState(() {
        serviceKitList = loadedKits;
        selectedServiceKitIndex = -1;
        selectedKitItems.clear();
        selectedKitItemsMap.clear();
      });

      debugPrint(
          ">> _fetchServiceKitsByBrandModel: Loaded ${loadedKits.length} kit(s).");
    } catch (e, stack) {
      debugPrint(">> _fetchServiceKitsByBrandModel ERROR: $e\n$stack");
      setState(() {
        serviceKitList = [];
        selectedServiceKitIndex = -1;
        selectedKitItems.clear();
        selectedKitItemsMap.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching service kits for $brand / $model: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _determineKitDisplayName(Map<String, dynamic> kit, int index) {
    final customName = kit["name"] ?? "";
    if (customName is String && customName.trim().isNotEmpty) {
      return customName;
    }
    return "Service Kit #$index";
  }

  Future<void> _fetchLocalOperators() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("partners")
          .where("partnershipType", isEqualTo: "Hospital")
          .get();
      List<Map<String, String>> list = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final persons = data["persons"];
        if (persons != null && persons is List) {
          for (var p in persons) {
            if (p is Map<String, dynamic>) {
              final name = p["name"]?.toString() ?? "";
              if (name.isNotEmpty) {
                list.add({"name": name});
              }
            }
          }
        }
      }
      setState(() {
        localOperatorList = list;
      });
      debugPrint(
          ">> _fetchLocalOperators: Retrieved ${localOperatorList.length} operator(s).");
    } catch (e) {
      debugPrint(">> _fetchLocalOperators ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching local operators: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _fetchFollowUpUsers() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection("users").get();
      List<Map<String, String>> list = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final firstName = data["firstName"]?.toString() ?? "";
        final lastName = data["lastName"]?.toString() ?? "";
        final fullName = "$firstName $lastName".trim();
        list.add({
          "id": doc.id, // Firestore doc ID
          "name": fullName,
        });
      }
      setState(() {
        followUpUserList = list;
      });
      debugPrint(
          ">> _fetchFollowUpUsers: Found ${followUpUserList.length} user(s).");
    } catch (e) {
      debugPrint(">> _fetchFollowUpUsers ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error fetching follow-up users: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ============================== DATE/TIME PICKERS ==============================

  Future<void> _pickIncidentDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: incidentDateTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: incidentDateTime != null
          ? TimeOfDay.fromDateTime(incidentDateTime!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      incidentDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickEstimatedEndingDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: estimatedEndingDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: estimatedEndingDate != null
          ? TimeOfDay.fromDateTime(estimatedEndingDate!)
          : TimeOfDay.now(),
    );
    if (time == null) return;
    setState(() {
      estimatedEndingDate =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  // ============================== IMAGE & FILE PICKERS ==============================

  Future<void> _pickDiagnosticPicture() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _diagnosticPictures.add(DiagnosticPicture(file: picked));
      });
    }
  }

  Widget _buildDiagnosticPictureItem(DiagnosticPicture diagPic, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: kIsWeb
                ? FutureBuilder<Uint8List>(
              future: diagPic.file.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    snapshot.hasData) {
                  return Image.memory(snapshot.data!, fit: BoxFit.cover);
                }
                return const Center(child: CircularProgressIndicator());
              },
            )
                : Image.file(File(diagPic.file.path), fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: diagPic.commentController,
              decoration: const InputDecoration(labelText: "Picture Comment"),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _diagnosticPictures.removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickReportFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _reportFile = result.files.first;
      });
    }
  }

  Future<List<Map<String, String>>> _uploadDiagnosticPictures() async {
    List<Map<String, String>> result = [];
    for (DiagnosticPicture diagPic in _diagnosticPictures) {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${diagPic.file.name}";
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("diagnosticPictures")
          .child(fileName);

      TaskSnapshot snap;
      if (kIsWeb) {
        final bytes = await diagPic.file.readAsBytes();
        snap = await storageRef.putData(bytes);
      } else {
        final localFile = File(diagPic.file.path);
        snap = await storageRef.putFile(localFile);
      }
      final downloadUrl = await snap.ref.getDownloadURL();
      result.add({
        "imageUrl": downloadUrl,
        "comment": diagPic.commentController.text.trim(),
      });
    }
    return result;
  }

  Future<String?> _uploadReportFile() async {
    if (_reportFile == null) return null;
    try {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${_reportFile!.name}";
      final storageRef = FirebaseStorage.instance
          .ref()
          .child("diagnosticReports")
          .child(fileName);

      TaskSnapshot snap;
      if (kIsWeb) {
        final bytes = _reportFile!.bytes;
        if (bytes == null) throw Exception("No bytes in _reportFile");
        snap = await storageRef.putData(bytes);
      } else {
        if (_reportFile!.path == null) {
          throw Exception("No local path for _reportFile");
        }
        final localFile = File(_reportFile!.path!);
        snap = await storageRef.putFile(localFile);
      }
      return await snap.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading report file: $e");
      return null;
    }
  }

  // ============================== CREATE TICKET ==============================

  Future<void> _createTicket() async {
    //
    // First, let the form validate the "Ticket Created By" field, etc.
    //
    if (!_formKey.currentState!.validate()) {
      debugPrint("[_createTicket] Form validation failed for 'Created By' or others.");
      return;
    }

    //
    // Next, we do a custom check for Title. If it's empty, show a box message (AlertDialog).
    //
    if (ticketTitleController.text.trim().isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Missing Title"),
          content: const Text("Please enter a Ticket Title."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
      return;
    }

    //
    // Check for missing dropdown fields
    //
    List<String> missingFields = [];
    if (selectedProjectDocId == null) missingFields.add("Project");
    if (selectedSiteId == null) missingFields.add("Site");
    if (selectedPSAId == null) missingFields.add("PSA");
    if (selectedLine == null) missingFields.add("Line");
    if (selectedEquipmentId == null) missingFields.add("Equipment");
    if (selectedSparePart == null) missingFields.add("SparePart");
    if (selectedLocalOperator == null) missingFields.add("Local Operator");

    if (missingFields.isNotEmpty) {
      final missingJoined = missingFields.join(", ");
      debugPrint("[_createTicket] Missing fields: $missingJoined");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please complete: $missingJoined"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // All required fields are set -> proceed
    final incidentTS = incidentDateTime != null
        ? Timestamp.fromDate(incidentDateTime!)
        : Timestamp.now();
    final estimatedEndingTS = estimatedEndingDate != null
        ? Timestamp.fromDate(estimatedEndingDate!)
        : null;
    final createdAt = Timestamp.now();

    // Gather selected service kit items
    List<String> selectedItemNames = [];
    if (selectedServiceKitIndex != null && selectedServiceKitIndex != -1) {
      selectedItemNames = selectedKitItemsMap.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();
    }

    // Show progress indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Upload pictures & optional file
      final uploadedPics = await _uploadDiagnosticPictures();
      final reportUrl = await _uploadReportFile();

      final ticketData = {
        "Afrimed_projectId": selectedProjectField,
        "projectNumber": selectedProjectField,

        "siteId": selectedSiteId,
        "siteName": selectedSiteName,
        "psaId": selectedPSAId,
        "psaReference": selectedPSAReference,
        "line": selectedLine,
        "equipmentId": selectedEquipmentId,
        "equipmentName": selectedEquipmentName,
        "equipmentBrand": selectedEquipmentBrand,
        "equipmentModel": selectedEquipmentModel,

        // Spare part
        "selectedSparePart": selectedSparePart,
        "sparePartAction": {
          "fix": fixSparePart,
          "replace": replaceSparePart,
        },

        // Service kit
        "selectedServiceKitIndex": selectedServiceKitIndex,
        "serviceKitAction": {
          "fix": fixServiceKit,
          "replace": replaceServiceKit,
        },
        "selectedKitItems": selectedItemNames,

        "localOperator": selectedLocalOperator,
        "ticketCreatedBy": ticketCreatedByController.text.trim(),

        "taskToBeFollowedByPerson1": selectedFollowUpUser1 ?? "",
        "taskToBeFollowedByPerson2": selectedFollowUpUser2 ?? "",

        //
        // NOTE: Removed "incident" field entirely.
        //
        "ticketTitle": ticketTitleController.text.trim(),
        "incidentDateTime": incidentTS,
        "estimatedEndingDate": estimatedEndingTS,
        "fixedAt": null,
        "equipmentStopped": equipmentStopped,
        "psaStopped": psaStopped,
        "underWarranty": underWarranty,
        "pictureList": uploadedPics,
        "reportFileUrl": reportUrl,
        "createdAt": createdAt,
      };

      // Create the curative maintenance ticket doc
      DocumentReference ticketRef = await FirebaseFirestore.instance
          .collection("curative_maintenance_tickets")
          .add(ticketData);

      // Create a corresponding task doc
      await FirebaseFirestore.instance.collection("tasks").add({
        "assignedTo": selectedFollowUpUser1 ?? "",
        "createdAt": createdAt,
        "createdBy": ticketCreatedByController.text.trim(),
        "createdByName": ticketCreatedByController.text.trim(),

        // No "incident" included
        "description": "",

        "endingDate": estimatedEndingTS,
        "phase": underWarranty ? "During Warranty" : "After Warranty",
        "priority": "Urgent",
        "projectId": selectedProjectDocId ?? "",
        "site": selectedSiteId,
        "startingDate": incidentTS,
        "status": "Pending",
        "title": ticketTitleController.text.trim(),
        "taskType": "Curative maintenance",
        "curativeTicketId": ticketRef.id,
      });

      // Close the progress indicator
      Navigator.of(context).pop();
      debugPrint("[_createTicket] Ticket created successfully, ID = ${ticketRef.id}");

      // Show success message & navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ticket created successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      Navigator.of(context).pop(); // Close the progress indicator
      debugPrint("Error creating ticket: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error creating ticket: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ============================== BUILD UI ==============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Curative Ticket"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------- Equipment Selection Section ----------
              const Text(
                "Equipment Selection",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),

              // Project Dropdown
              FutureBuilder(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      projectList.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (projectList.isEmpty) {
                    return const Text("No projects found.");
                  }
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Project"),
                    value: selectedProjectDocId,
                    items: projectList.map((proj) {
                      return DropdownMenuItem<String>(
                        value: proj["docId"],
                        child: Text(proj["projectField"]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedProjectDocId = value;
                        final chosen =
                        projectList.firstWhere((p) => p["docId"] == value);
                        selectedProjectField = chosen["projectField"];

                        // Reset dependent
                        siteList.clear();
                        psaList.clear();
                        lineReferences.clear();
                        selectedSiteId = null;
                        selectedSiteName = null;
                        selectedPSAId = null;
                        selectedPSAReference = null;
                        selectedLine = null;
                        selectedEquipmentId = null;
                        selectedEquipmentName = null;
                        sparePartsList.clear();
                        selectedSparePart = "No spare part";
                        fixSparePart = false;
                        replaceSparePart = false;
                        serviceKitList.clear();
                        selectedServiceKitIndex = -1;
                        selectedKitItems.clear();
                        selectedKitItemsMap.clear();

                        if (selectedProjectDocId != null) {
                          _fetchSites(selectedProjectDocId!);
                        }
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 12),

              // Site Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Site"),
                value: selectedSiteName,
                items: siteList.map((site) {
                  return DropdownMenuItem<String>(
                    value: site["siteName"],
                    child: Text(site["siteName"]),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSiteName = value;
                    final chosen =
                    siteList.firstWhere((s) => s["siteName"] == value);
                    selectedSiteId = chosen["id"];

                    // Reset
                    psaList.clear();
                    lineReferences.clear();
                    selectedPSAId = null;
                    selectedPSAReference = null;
                    selectedLine = null;
                    selectedEquipmentId = null;
                    selectedEquipmentName = null;
                    equipmentList.clear();
                    sparePartsList.clear();
                    selectedSparePart = "No spare part";
                    fixSparePart = false;
                    replaceSparePart = false;
                    serviceKitList.clear();
                    selectedServiceKitIndex = -1;
                    selectedKitItems.clear();
                    selectedKitItemsMap.clear();

                    if (selectedProjectField != null && selectedSiteId != null) {
                      _fetchPSA(selectedProjectField!, selectedSiteId!);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // PSA Reference Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "PSA Reference"),
                value: selectedPSAReference,
                items: psaList.map((psa) {
                  return DropdownMenuItem<String>(
                    value: psa["reference"],
                    child: Text(psa["reference"]),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedPSAReference = value;
                    final chosenPSA =
                    psaList.firstWhere((p) => p["reference"] == value);
                    selectedPSAId = chosenPSA["id"];

                    if (chosenPSA["lineReferences"] != null &&
                        chosenPSA["lineReferences"] is Map) {
                      lineReferences =
                      Map<String, String>.from(chosenPSA["lineReferences"]);
                    } else {
                      lineReferences.clear();
                    }

                    // Reset
                    selectedLine = null;
                    selectedEquipmentId = null;
                    selectedEquipmentName = null;
                    equipmentList.clear();
                    sparePartsList.clear();
                    selectedSparePart = "No spare part";
                    fixSparePart = false;
                    replaceSparePart = false;
                    serviceKitList.clear();
                    selectedServiceKitIndex = -1;
                    selectedKitItems.clear();
                    selectedKitItemsMap.clear();
                  });
                },
              ),
              const SizedBox(height: 12),

              // PSA Line Dropdown
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Line"),
                value: selectedLine,
                items: lineReferences.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedLine = value;
                    selectedEquipmentId = null;
                    selectedEquipmentName = null;
                    equipmentList.clear();
                    sparePartsList.clear();
                    selectedSparePart = "No spare part";
                    fixSparePart = false;
                    replaceSparePart = false;
                    serviceKitList.clear();
                    selectedServiceKitIndex = -1;
                    selectedKitItems.clear();
                    selectedKitItemsMap.clear();

                    if (selectedPSAReference != null && selectedLine != null) {
                      _fetchEquipment(selectedPSAReference!, selectedLine!);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // Equipment Dropdown
              DropdownButtonFormField<String>(
                decoration:
                const InputDecoration(labelText: "Concerned Equipment"),
                value: selectedEquipmentName,
                items: equipmentList.map((equip) {
                  return DropdownMenuItem<String>(
                    value: equip["name"],
                    child: Text(equip["name"]),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEquipmentName = value;
                    final chosenEquip =
                    equipmentList.firstWhere((e) => e["name"] == value);
                    selectedEquipmentId = chosenEquip["id"];
                    selectedEquipmentBrand = chosenEquip["brand"];
                    selectedEquipmentModel = chosenEquip["model"];

                    // Reset
                    sparePartsList.clear();
                    selectedSparePart = "No spare part";
                    fixSparePart = false;
                    replaceSparePart = false;
                    serviceKitList.clear();
                    selectedServiceKitIndex = -1;
                    selectedKitItems.clear();
                    selectedKitItemsMap.clear();

                    // Fetch parts/kits
                    _fetchSparePartsByBrandModel(
                        selectedEquipmentBrand!, selectedEquipmentModel!);
                    _fetchServiceKitsByBrandModel(
                        selectedEquipmentBrand!, selectedEquipmentModel!);
                  });
                },
              ),
              const SizedBox(height: 12),

              // Spare Parts Dropdown (+ "No spare part" option)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Spare Part"),
                value: selectedSparePart,
                items: [
                  const DropdownMenuItem<String>(
                    value: "No spare part",
                    child: Text("No spare part"),
                  ),
                  ...sparePartsList.map((sp) {
                    return DropdownMenuItem<String>(
                      value: sp["name"],
                      child: Text(sp["name"]),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedSparePart = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Spare Part Action Checkboxes
              const Text("Spare Part Action",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text("Fix the selected spare part"),
                value: fixSparePart,
                onChanged: (val) {
                  setState(() {
                    fixSparePart = val ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("Replace the selected spare part"),
                value: replaceSparePart,
                onChanged: (val) {
                  setState(() {
                    replaceSparePart = val ?? false;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Service Kit Dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Service Kit"),
                value: selectedServiceKitIndex,
                items: [
                  const DropdownMenuItem<int>(
                    value: -1,
                    child: Text("No service kit concerned"),
                  ),
                  ...List.generate(serviceKitList.length, (index) {
                    final kitMap = serviceKitList[index];
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(kitMap["name"] ?? "Unnamed Kit #$index"),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedServiceKitIndex = value;
                    if (value == null || value == -1) {
                      selectedKitItems.clear();
                      selectedKitItemsMap.clear();
                      return;
                    }
                    final kit = serviceKitList[value];
                    final kitItems = kit["items"] ?? [];
                    if (kitItems is List) {
                      selectedKitItems =
                      List<Map<String, dynamic>>.from(kitItems);
                    } else {
                      selectedKitItems = [];
                    }
                    selectedKitItemsMap.clear();
                    for (var item in selectedKitItems) {
                      final itemName =
                          item["name"]?.toString() ?? "Unnamed Item";
                      selectedKitItemsMap[itemName] = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              if (selectedKitItems.isNotEmpty) ...[
                const Text("Select the items in the chosen Service Kit:",
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
                ...selectedKitItems.map((item) {
                  final itemName = item["name"]?.toString() ?? "Unnamed Item";
                  return CheckboxListTile(
                    title: Text(itemName),
                    value: selectedKitItemsMap[itemName] ?? false,
                    onChanged: (val) {
                      setState(() {
                        selectedKitItemsMap[itemName] = val ?? false;
                      });
                    },
                  );
                }).toList(),
              ],
              const SizedBox(height: 12),

              // Service Kit Action
              const Text("Service Kit Action",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                title: const Text("Fix the selected service kit item(s)"),
                value: fixServiceKit,
                onChanged: (val) {
                  setState(() {
                    fixServiceKit = val ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("Replace the selected service kit item(s)"),
                value: replaceServiceKit,
                onChanged: (val) {
                  setState(() {
                    replaceServiceKit = val ?? false;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Local Operator
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                    labelText: "Hôpital operator that reported incident"),
                value: selectedLocalOperator,
                items: localOperatorList.map((op) {
                  return DropdownMenuItem<String>(
                    value: op["name"],
                    child: Text(op["name"]!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedLocalOperator = value;
                  });
                },
                validator: (val) => (val == null || val.isEmpty)
                    ? "Select a local operator"
                    : null,
              ),
              const SizedBox(height: 12),

              // Follow-up user (1)
              DropdownButtonFormField<String>(
                decoration:
                const InputDecoration(labelText: "Ticket followed by (1)"),
                value: selectedFollowUpUser1,
                items: followUpUserList.map((user) {
                  return DropdownMenuItem<String>(
                    value: user["id"],
                    child: Text(user["name"] ?? ""),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFollowUpUser1 = value;
                  });
                },
              ),
              const SizedBox(height: 8),

              // Follow-up user (2)
              DropdownButtonFormField<String>(
                decoration:
                const InputDecoration(labelText: "Ticket followed by (2)"),
                value: selectedFollowUpUser2,
                items: followUpUserList.map((user) {
                  return DropdownMenuItem<String>(
                    value: user["id"],
                    child: Text(user["name"] ?? ""),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFollowUpUser2 = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Incident Date & Time
              ListTile(
                title: Text(
                  incidentDateTime == null
                      ? "Select Incident Date & Time"
                      : "Incident: ${incidentDateTime!.toLocal().toString().split('.').first}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickIncidentDateTime,
              ),
              const SizedBox(height: 12),

              // Estimated Ending Date & Time
              ListTile(
                title: Text(
                  estimatedEndingDate == null
                      ? "Select Estimated Ending Date & Time"
                      : "Estimated Ending: ${estimatedEndingDate!.toLocal().toString().split('.').first}",
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickEstimatedEndingDateTime,
              ),
              const SizedBox(height: 12),

              // Checkboxes
              CheckboxListTile(
                title: const Text("Equipment Stopped"),
                value: equipmentStopped,
                onChanged: (val) {
                  setState(() {
                    equipmentStopped = val ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("PSA Stopped"),
                value: psaStopped,
                onChanged: (val) {
                  setState(() {
                    psaStopped = val ?? false;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text("Under Warranty"),
                value: underWarranty,
                onChanged: (val) {
                  setState(() {
                    underWarranty = val ?? false;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Incident Details (Title only)
              const Text(
                "Incident Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              // TICKET TITLE - no validator here, we'll show an AlertDialog if empty
              TextFormField(
                controller: ticketTitleController,
                decoration: const InputDecoration(labelText: "Ticket Title"),
              ),
              const SizedBox(height: 12),

              // Created By (still validated)
              TextFormField(
                controller: ticketCreatedByController,
                decoration:
                const InputDecoration(labelText: "Ticket Created by"),
                validator: (val) => (val == null || val.isEmpty)
                    ? "Enter the creator's name"
                    : null,
              ),
              const SizedBox(height: 12),

              // Pictures & Comments
              const Text("Pictures & Comments",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Column(
                children: _diagnosticPictures
                    .asMap()
                    .entries
                    .map((entry) =>
                    _buildDiagnosticPictureItem(entry.value, entry.key))
                    .toList(),
              ),
              ElevatedButton.icon(
                onPressed: _pickDiagnosticPicture,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("Add Picture"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6)),
              ),
              const SizedBox(height: 12),

              // Optional file
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Upload initial diagnostic report (PDF/Word) (Optional)",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _reportFile != null
                            ? _reportFile!.name
                            : "No file selected.",
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickReportFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Select Diagnostic Report"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0073E6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Create Ticket Button
              ElevatedButton(
                onPressed: _createTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                ),
                child: const Text("Create Ticket"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
