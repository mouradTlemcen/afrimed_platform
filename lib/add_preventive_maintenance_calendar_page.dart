import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AddPreventiveMaintenanceCalendarPage extends StatefulWidget {
  @override
  _AddPreventiveMaintenanceCalendarPageState createState() =>
      _AddPreventiveMaintenanceCalendarPageState();
}

class _AddPreventiveMaintenanceCalendarPageState
    extends State<AddPreventiveMaintenanceCalendarPage> {
  final _formKey = GlobalKey<FormState>();

  // Calendar title
  final TextEditingController _calendarTitleController =
  TextEditingController(text: "Calendar_PPM_");

  // Start/end date, period, and generated schedule
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _periodController = TextEditingController();
  List<DateTime> _scheduleDates = [];
  bool _isDeployed = false;

  // Project-related
  List<DocumentSnapshot> _projects = [];
  String? selectedProjectDocId;
  String projectNumber = "";

  // Site-related
  List<DocumentSnapshot> _allSites = [];
  List<DocumentSnapshot> _availableSites = [];
  String? selectedSiteDocId;
  String selectedSiteName = "";

  // For filtering out sites that already have calendars
  Set<String> _sitesWithCalendar = {};

  // PSA references
  List<DocumentSnapshot> _psaReferences = [];
  String? selectedPSADocId;
  String selectedPSARef = "";

  // Equipment from the selected PSA
  List<_EquipmentChoice> _psaEquipmentChoices = [];
  List<String> selectedEquipment = [];

  bool isLoadingProjects = false;
  bool isLoadingSites = false;
  bool isLoadingPSA = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  @override
  void dispose() {
    _calendarTitleController.dispose();
    _periodController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------------
  // 1) FETCH ALL PROJECTS
  // -----------------------------------------------------------------------------
  Future<void> _fetchProjects() async {
    setState(() => isLoadingProjects = true);
    try {
      QuerySnapshot snapshot =
      await FirebaseFirestore.instance.collection('projects').get();
      setState(() {
        _projects = snapshot.docs;
      });
    } catch (e, stack) {
      debugPrint("Error fetching projects: $e");
      debugPrint("Stack: $stack");
    } finally {
      setState(() => isLoadingProjects = false);
    }
  }

  // -----------------------------------------------------------------------------
  // 2) FETCH ALL SITES FOR THE CHOSEN PROJECT AND FILTER OUT THOSE WITH CALENDARS
  // -----------------------------------------------------------------------------
  Future<void> _fetchSitesForProject(String projectDocId) async {
    setState(() {
      isLoadingSites = true;
      _allSites = [];
      _availableSites = [];
      selectedSiteDocId = null;
      selectedSiteName = "";
      _sitesWithCalendar = {};
    });

    try {
      // 1) Get all sites for the project (as before)
      QuerySnapshot lotsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectDocId)
          .collection('lots')
          .get();

      List<DocumentSnapshot> sitesList = [];
      for (var lotDoc in lotsSnapshot.docs) {
        QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectDocId)
            .collection('lots')
            .doc(lotDoc.id)
            .collection('sites')
            .get();
        sitesList.addAll(siteSnapshot.docs);
      }
      _allSites = sitesList;

      // 2) Get all existing preventive maintenance calendars for this project
      QuerySnapshot pmCalendarsSnapshot = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .where('projectNumber',
          isEqualTo: (_projects
              .firstWhere((doc) => doc.id == projectDocId)
              .data() as Map<String, dynamic>)['Afrimed_projectId'])
          .get();

      // 3) Build a set of site names that already have a calendar
      Set<String> sitesWithCalendar = {};
      for (var calendarDoc in pmCalendarsSnapshot.docs) {
        final data = calendarDoc.data() as Map<String, dynamic>;
        if (data['site'] != null) {
          sitesWithCalendar.add(data['site']);
        }
      }
      _sitesWithCalendar = sitesWithCalendar;

      // 4) Filter out sites that are in the set
      _availableSites = _allSites.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final siteName = data['siteName'] ?? '';
        return !_sitesWithCalendar.contains(siteName);
      }).toList();

      setState(() {});
    } catch (e, stack) {
      debugPrint("Error fetching sites: $e");
      debugPrint("Stack: $stack");
    } finally {
      setState(() => isLoadingSites = false);
    }
  }

  // -----------------------------------------------------------------------------
  // 3) FETCH PSA REFERENCES
  // -----------------------------------------------------------------------------
  Future<void> _fetchPSAReferencesForProject(String projectNum) async {
    if (selectedSiteDocId == null) {
      debugPrint("No site selected; returning.");
      return;
    }
    setState(() {
      isLoadingPSA = true;
      _psaReferences = [];
      selectedPSADocId = null;
      selectedPSARef = "";
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('psa_units')
          .where('Afrimed_projectId', isEqualTo: projectNum)
          .where('siteId', isEqualTo: selectedSiteDocId)
          .get();

      setState(() {
        _psaReferences = snapshot.docs;
      });
      if (_psaReferences.isEmpty) {
        debugPrint("No PSA references found for projectNum='$projectNum' and siteId='$selectedSiteDocId'.");
      }
    } catch (e, stack) {
      debugPrint("Error fetching PSA references: $e");
      debugPrint("Stack: $stack");
    } finally {
      setState(() => isLoadingPSA = false);
    }
  }

  // -----------------------------------------------------------------------------
  // 4) FETCH EQUIPMENT LIST FOR THE SELECTED PSA
  // -----------------------------------------------------------------------------
  Future<void> _fetchEquipmentListForPSA() async {
    if (selectedPSADocId == null) {
      debugPrint("No PSA doc ID selected; returning.");
      return;
    }
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(selectedPSADocId)
          .collection('PSA_linked_equipment_list')
          .get();

      List<_EquipmentChoice> newChoices = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        final eqId = data['equipmentId'] as String?;
        if (eqId == null ||
            eqId.toLowerCase() == "not concerned" ||
            eqId.isEmpty) {
          continue;
        }

        final eqSnap = await FirebaseFirestore.instance
            .collection('acquired_equipments')
            .doc(eqId)
            .get();
        if (eqSnap.exists) {
          final eqData = eqSnap.data() as Map<String, dynamic>;
          final equipmentType = eqData['equipmentType'] ?? "Type?";
          final brand = eqData['brand'] ?? "Brand?";
          final model = eqData['model'] ?? "Model?";
          final serial = eqData['serialNumber'] ?? "SN?";

          final psDocId = doc.id;
          final parts = psDocId.split('_');
          final lineRef = parts.isNotEmpty ? parts[0] : "Ref?";

          final label = "($lineRef)/$equipmentType/$brand/$model/$serial";
          newChoices.add(_EquipmentChoice(docId: eqId, label: label));
        }
      }
      setState(() {
        _psaEquipmentChoices = newChoices;
        selectedEquipment.clear();
      });
    } catch (e, stack) {
      debugPrint("Error fetching equipment list for PSA: $e");
      debugPrint("Stack: $stack");
    }
  }

  // -----------------------------------------------------------------------------
  // GENERATE SCHEDULE
  // -----------------------------------------------------------------------------
  void _generateScheduleDates() {
    _scheduleDates.clear();
    if (_startDate == null ||
        _endDate == null ||
        _periodController.text.isEmpty) {
      return;
    }
    final months = int.tryParse(_periodController.text.trim());
    if (months == null || months <= 0) {
      return;
    }
    DateTime current = _startDate!;
    while (current.isBefore(_endDate!) || current.isAtSameMomentAs(_endDate!)) {
      _scheduleDates.add(current);
      current = DateTime(current.year, current.month + months, current.day);
    }
  }

  // -----------------------------------------------------------------------------
  // DEPLOY -> GENERATE & SHOW THE SCHEDULE
  // -----------------------------------------------------------------------------
  void _deployCalendar() {
    if (_startDate == null ||
        _endDate == null ||
        _periodController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select valid start/end dates and a period."),
        ),
      );
      return;
    }
    _generateScheduleDates();
    setState(() {
      _isDeployed = true;
    });
  }

  // -----------------------------------------------------------------------------
  // SAVE CALENDAR TO "preventive_maintenance"
  // -----------------------------------------------------------------------------
  Future<void> _saveCalendar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedProjectDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a project.")),
      );
      return;
    }
    if (selectedSiteDocId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a site.")),
      );
      return;
    }
    if (selectedPSARef.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a PSA reference.")),
      );
      return;
    }
    if (_startDate == null || _endDate == null || _scheduleDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please deploy a valid schedule.")),
      );
      return;
    }
    if (selectedEquipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one equipment.")),
      );
      return;
    }

    final selectedEquipmentDetails = _psaEquipmentChoices
        .where((choice) => selectedEquipment.contains(choice.docId))
        .map((choice) => {
      'docId': choice.docId,
      'label': choice.label,
    })
        .toList();

    try {
      final List<Timestamp> scheduleTimestamps =
      _scheduleDates.map((dt) => Timestamp.fromDate(dt)).toList();

      await FirebaseFirestore.instance.collection('preventive_maintenance').add({
        'calendarTitle': _calendarTitleController.text.trim(),
        'projectNumber': projectNumber,
        'site': selectedSiteName,
        'psaReference': selectedPSARef,
        'equipmentList': selectedEquipmentDetails,
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'scheduleDates': scheduleTimestamps,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Calendar created successfully!")),
      );
      Navigator.pop(context);
    } catch (e, stack) {
      debugPrint("Error saving calendar: $e");
      debugPrint("Stack: $stack");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating calendar: $e")),
      );
    }
  }

  // -----------------------------------------------------------------------------
  // PICK START DATE
  // -----------------------------------------------------------------------------
  Future<void> _pickStartDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  // -----------------------------------------------------------------------------
  // PICK END DATE
  // -----------------------------------------------------------------------------
  Future<void> _pickEndDate() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  // -----------------------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Preventive Maintenance Calendar"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CALENDAR TITLE
                  TextFormField(
                    controller: _calendarTitleController,
                    decoration: const InputDecoration(
                      labelText: "Calendar Title",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => (value!.isEmpty)
                        ? "Please enter a calendar title"
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // SELECT PROJECT
                  const Text(
                    "Select Project:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedProjectDocId,
                      underline: const SizedBox(),
                      hint: isLoadingProjects
                          ? const Text("Loading projects...")
                          : const Text("Choose Project"),
                      items: _projects.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final pNum = data['Afrimed_projectId'] ?? 'Unknown';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(pNum),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedProjectDocId = value;
                          selectedSiteDocId = null;
                          selectedSiteName = "";
                          _psaReferences = [];
                          selectedPSADocId = null;
                          selectedPSARef = "";
                          _psaEquipmentChoices.clear();
                        });
                        if (value != null) {
                          final doc = _projects.firstWhere((d) => d.id == value);
                          final data = doc.data() as Map<String, dynamic>;
                          projectNumber = data['Afrimed_projectId'] ?? 'Unknown';
                          _fetchSitesForProject(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SELECT SITE
                  const Text(
                    "Select Site:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedSiteDocId,
                      underline: const SizedBox(),
                      hint: isLoadingSites
                          ? const Text("Loading sites...")
                          : const Text("Choose Site"),
                      items: _availableSites.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final sName = data['siteName'] ?? 'Unnamed Site';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(sName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedSiteDocId = value;
                          if (value != null) {
                            final doc =
                            _availableSites.firstWhere((d) => d.id == value);
                            final data = doc.data() as Map<String, dynamic>;
                            selectedSiteName = data['siteName'] ?? 'Unnamed Site';
                          }
                        });
                        if (projectNumber.isNotEmpty &&
                            selectedSiteDocId != null) {
                          _fetchPSAReferencesForProject(projectNumber);
                        }
                      },
                    ),
                  ),
                  if (_sitesWithCalendar.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        "Sites hidden because they already have a calendar: ${_sitesWithCalendar.join(', ')}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // SELECT PSA REFERENCE
                  const Text(
                    "Select PSA Reference:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedPSADocId,
                      underline: const SizedBox(),
                      hint: isLoadingPSA
                          ? const Text("Loading PSA references...")
                          : _psaReferences.isEmpty
                          ? const Text("No PSA references found")
                          : const Text("Choose PSA Reference"),
                      items: _psaReferences.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ref = data['reference'] ?? 'No Reference';
                        return DropdownMenuItem(
                          value: doc.id,
                          child: Text(ref),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedPSADocId = value;
                          if (value != null) {
                            final doc =
                            _psaReferences.firstWhere((d) => d.id == value);
                            final data = doc.data() as Map<String, dynamic>;
                            selectedPSARef = data['reference'] ?? "";
                            _calendarTitleController.text =
                            "Calendar_PPM_${selectedPSARef}_1";
                          }
                        });
                        _fetchEquipmentListForPSA();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SELECT EQUIPMENT
                  const Text(
                    "Select Equipment:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (_psaEquipmentChoices.isEmpty)
                    const Text(
                      "No equipment found or 'Not Concerned'.",
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: _psaEquipmentChoices.map((choice) {
                        bool isSelected =
                        selectedEquipment.contains(choice.docId);
                        return CheckboxListTile(
                          title: Text(choice.label),
                          value: isSelected,
                          onChanged: (bool? val) {
                            setState(() {
                              if (val == true) {
                                selectedEquipment.add(choice.docId);
                              } else {
                                selectedEquipment.remove(choice.docId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),

                  // MAINTENANCE SCHEDULE
                  const Text(
                    "Maintenance Schedule",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickStartDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _startDate == null
                            ? "Select Start Date"
                            : DateFormat('yyyy-MM-dd').format(_startDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _endDate == null
                            ? "Select End Date"
                            : DateFormat('yyyy-MM-dd').format(_endDate!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PERIOD (MONTHS)
                  TextFormField(
                    controller: _periodController,
                    decoration: const InputDecoration(
                      labelText: "Period (months)",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => (value!.isEmpty)
                        ? "Enter period in months"
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // DEPLOY BUTTON
                  ElevatedButton(
                    onPressed: _deployCalendar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0073E6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Deploy Calendar"),
                  ),
                  const SizedBox(height: 16),

                  // SHOW SCHEDULE
                  _isDeployed && _scheduleDates.isNotEmpty
                      ? Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Scheduled Dates:",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("No.")),
                                DataColumn(label: Text("Date")),
                              ],
                              rows: List.generate(_scheduleDates.length,
                                      (index) {
                                    DateTime dt = _scheduleDates[index];
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                            Text((index + 1).toString())),
                                        DataCell(Text(DateFormat('yyyy-MM-dd')
                                            .format(dt))),
                                      ],
                                    );
                                  }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : Container(),
                  const SizedBox(height: 24),

                  // SAVE BUTTON
                  ElevatedButton(
                    onPressed: _saveCalendar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Save Calendar"),
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

/// Helper class for showing equipment in a checkbox list.
class _EquipmentChoice {
  final String docId;
  final String label;

  _EquipmentChoice({required this.docId, required this.label});
}
