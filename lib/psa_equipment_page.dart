import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PSAEquipmentPage extends StatefulWidget {
  final String psaReference;
  final String psaId; // Firestore PSA Document ID
  final String afrimedProjectId; // Business-friendly project identifier
  final String projectDocId; // Actual Firestore document ID for the project

  const PSAEquipmentPage({
    required this.psaReference,
    required this.psaId,
    required this.afrimedProjectId,
    required this.projectDocId,
    Key? key,
  }) : super(key: key);

  @override
  _PSAEquipmentPageState createState() => _PSAEquipmentPageState();
}

class _PSAEquipmentPageState extends State<PSAEquipmentPage> {
  // List of equipment types.
  final List<String> _equipmentTypes = [
    "Room",
    "Container",
    "Skid",
    "Electrical Panel",
    "Compressor",
    "Dryer",
    "Pneumatic System",
    "Oxygen Generator",
    "Air Tank",
    "Oxygen Tank",
    "Booster",
    "Filling Ramp",
    "Backup Ramp",
    "MGPS",
  ];

  // Equipment types that allow a "Not Concerned" option.
  final Set<String> _notConcernedTypes = {
    "Room",
    "Container",
    "Skid",
    "Booster",
    "Filling Ramp",
    "Backup Ramp",
    "MGPS",
  };

  // Each line's selections: { lineNumber: { equipmentType: equipmentIdOrNotConcerned } }
  Map<int, Map<String, String?>> _selectedEquipment = {
    1: {},
    2: {},
  };

  /// If true, Line 1 is fully saved/linked and should no longer be editable.
  bool _line1Saved = false;

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _loadLine1DataIfExists();
  }

  // Initialize the selection maps with default values.
  void _initializeSelections() {
    for (int line = 1; line <= 2; line++) {
      _selectedEquipment[line] = {};
      for (String type in _equipmentTypes) {
        if (_notConcernedTypes.contains(type)) {
          _selectedEquipment[line]![type] = "Not Concerned";
        } else {
          _selectedEquipment[line]![type] = null;
        }
      }
    }
  }

  /// Loads existing data for Line 1 from the subcollection "PSA_linked_equipment_list".
  Future<void> _loadLine1DataIfExists() async {
    final line1Ref = FirebaseFirestore.instance
        .collection('psa_units')
        .doc(widget.psaId)
        .collection('PSA_linked_equipment_list');

    bool isComplete = true;

    for (String type in _equipmentTypes) {
      final docKey = "line1_$type";
      final docSnap = await line1Ref.doc(docKey).get();
      if (!docSnap.exists) {
        debugPrint(">> MISSING doc for $docKey");
        isComplete = false;
      } else {
        final data = docSnap.data() as Map<String, dynamic>;
        final equipId = data['equipmentId'] as String?;
        if (equipId == null) {
          debugPrint(">> doc $docKey has null equipmentId!");
          isComplete = false;
        } else {
          debugPrint(">> doc $docKey is OK with equipmentId=$equipId");
          _selectedEquipment[1]![type] = equipId;
        }
      }
    }

    if (isComplete) {
      setState(() {
        _line1Saved = true;
      });
    }
  }

  /// Fetch equipment docs of the given type from "acquired_equipments".
  Future<List<DocumentSnapshot>> _fetchEquipmentDocs(String type) async {
    final snap = await FirebaseFirestore.instance
        .collection('acquired_equipments')
        .where('equipmentType', isEqualTo: type)
        .get();
    return snap.docs;
  }

  /// Builds a dropdown for the given line and equipment type.
  Widget _buildDropdown(int line, String type) {
    final currentVal = _selectedEquipment[line]![type];

    return FutureBuilder<List<DocumentSnapshot>>(
      future: _fetchEquipmentDocs(type),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 24,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        List<DocumentSnapshot> docs = snapshot.data!;

        // Exclude docs that are linked to a PSA (except if it's the current selection).
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['linkedStatus'];
          if (status != null &&
              status is String &&
              status.startsWith("Linked to")) {
            return currentVal == doc.id;
          }
          return true;
        }).toList();

        // For line 2, exclude equipment already chosen in line 1.
        if (line == 2) {
          final usedInLine1 = _selectedEquipment[1]!.values
              .where((val) => val != null && val != "Not Concerned")
              .cast<String>()
              .toSet();
          docs = docs.where((doc) => !usedInLine1.contains(doc.id)).toList();
        }

        final items = <DropdownMenuItem<String>>[];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final brand = data['brand'] ?? "Brand?";
          final model = data['model'] ?? "Model?";
          final serial = data['serialNumber'] ?? "Serial?";
          final display = "$brand - $model - $serial";
          items.add(DropdownMenuItem<String>(
            value: doc.id,
            child: Text(display),
          ));
        }

        // Add "Not Concerned" option if applicable.
        if (_notConcernedTypes.contains(type) &&
            !items.any((item) => item.value == "Not Concerned")) {
          items.add(const DropdownMenuItem<String>(
            value: "Not Concerned",
            child: Text("Not Concerned", style: TextStyle(color: Colors.green)),
          ));
        }

        // If the current value isn't already in the list, insert it.
        if (currentVal != null && !items.any((i) => i.value == currentVal)) {
          items.insert(
            0,
            DropdownMenuItem<String>(
              value: currentVal,
              child: Text(currentVal),
            ),
          );
        }

        final bool disableDropdown = (line == 1 && _line1Saved);
        return DropdownButtonFormField<String>(
          value: currentVal,
          items: items,
          onChanged: disableDropdown
              ? null
              : (val) {
            setState(() {
              _selectedEquipment[line]![type] = val;
            });
          },
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: const OutlineInputBorder(),
            labelStyle: disableDropdown ? const TextStyle(color: Colors.grey) : null,
          ),
          style: disableDropdown ? const TextStyle(color: Colors.grey) : null,
        );
      },
    );
  }

  /// Builds a data table for a given line.
  Widget _buildDataTable(int line) {
    final bool isLine1Locked = (line == 1 && _line1Saved);
    final textColor = isLine1Locked ? Colors.grey : Colors.black;

    final rows = _equipmentTypes.map((type) {
      return DataRow(
        cells: [
          DataCell(Text(
            type,
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          )),
          DataCell(_buildDropdown(line, type)),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blueGrey.shade50),
        columns: [
          DataColumn(
            label: Text("Equipment Type", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
          DataColumn(
            label: Text("Select Equipment", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          ),
        ],
        rows: rows,
      ),
    );
  }

  /// Save function for Line 1.
  Future<void> _saveLine1() async {
    if (_line1Saved) return;
    for (String type in _equipmentTypes) {
      if (_selectedEquipment[1]![type] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please complete $type for Line 1.")),
        );
        return;
      }
    }

    try {
      final psaRef = FirebaseFirestore.instance.collection('psa_units').doc(widget.psaId);
      final batch = FirebaseFirestore.instance.batch();

      for (String type in _equipmentTypes) {
        final selection = _selectedEquipment[1]![type];
        final docKey = "line1_$type";
        final docRef = psaRef.collection('PSA_linked_equipment_list').doc(docKey);

        if (selection == "Not Concerned") {
          batch.set(docRef, {
            'equipmentReferenceNumber': "Not Concerned",
            'equipmentId': "Not Concerned",
            'Afrimed_projectId': widget.afrimedProjectId,
            'projectDocId': widget.projectDocId,
          });
        } else {
          final equipRef = FirebaseFirestore.instance
              .collection('acquired_equipments')
              .doc(selection);
          batch.set(
            equipRef,
            {
              'linkedToPSA': widget.psaReference,
              'linkedStatus': 'Linked to ${widget.psaReference}',
              'Afrimed_projectId': widget.afrimedProjectId,
              'projectDocId': widget.projectDocId,
            },
            SetOptions(merge: true),
          );

          batch.set(docRef, {
            'equipmentReferenceNumber': "ref_line1_$type",
            'equipmentId': selection,
            'Afrimed_projectId': widget.afrimedProjectId,
            'projectDocId': widget.projectDocId,
          });
        }
      }

      await batch.commit();

      setState(() {
        _line1Saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Line 1 saved successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving Line 1: $e")),
      );
    }
  }

  /// Save function for Line 2.
  Future<void> _saveLine2() async {
    for (String type in _equipmentTypes) {
      if (_selectedEquipment[2]![type] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please complete $type for Line 2.")),
        );
        return;
      }
    }

    try {
      final psaRef = FirebaseFirestore.instance.collection('psa_units').doc(widget.psaId);
      final batch = FirebaseFirestore.instance.batch();

      for (String type in _equipmentTypes) {
        final selection = _selectedEquipment[2]![type];
        final docKey = "line2_$type";
        final docRef = psaRef.collection('PSA_linked_equipment_list').doc(docKey);

        if (selection == "Not Concerned") {
          batch.set(docRef, {
            'equipmentReferenceNumber': "Not Concerned",
            'equipmentId': "Not Concerned",
            'Afrimed_projectId': widget.afrimedProjectId,
            'projectDocId': widget.projectDocId,
          });
        } else {
          final equipRef = FirebaseFirestore.instance
              .collection('acquired_equipments')
              .doc(selection);
          batch.set(
            equipRef,
            {
              'linkedToPSA': widget.psaReference,
              'linkedStatus': 'Linked to ${widget.psaReference}',
              'Afrimed_projectId': widget.afrimedProjectId,
              'projectDocId': widget.projectDocId,
            },
            SetOptions(merge: true),
          );

          batch.set(docRef, {
            'equipmentReferenceNumber': "ref_line2_$type",
            'equipmentId': selection,
            'Afrimed_projectId': widget.afrimedProjectId,
            'projectDocId': widget.projectDocId,
          });
        }
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Line 2 saved successfully.")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving Line 2: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Equipment for ${widget.psaReference}"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: (_line1Saved) ? _buildLine2Only() : _buildLine1Only(),
    );
  }

  Widget _buildLine1Only() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Line 1", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDataTable(1),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: _saveLine1,
                    child: const Text("Save Table of Line 1"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLine2Only() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Line 2", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDataTable(2),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton(
                    onPressed: _saveLine2,
                    child: const Text("Save Table of Line 2"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
