/*
File: EditPSAPage.dart
Description:
  This page allows users to edit a PSA unit. It shows the current PSA details and lets the user update
  the installation and commissioning dates (and add comments). When the user saves the dates, a message box
  is displayed stating that the dates are saved. When the user clicks "OK" on the dialog, the date fields
  become locked (greyed out) and then the page is closed.
*/

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditPSAPage extends StatefulWidget {
  final String psaId; // Unique PSA document ID in Firestore
  final Map<String, dynamic> psaData; // Current PSA details

  const EditPSAPage({required this.psaId, required this.psaData, Key? key})
      : super(key: key);

  @override
  _EditPSAPageState createState() => _EditPSAPageState();
}

class _EditPSAPageState extends State<EditPSAPage> {
  Map<int, Map<String, String?>> selectedEquipmentByLine = {};
  String? projectNumber;
  String? lotName;
  String? siteName;
  bool allEquipmentAdded = false;

  // Ensure numLines is declared at the class level.
  int numLines = 1;

  // Controllers for the date fields and comment field.
  final TextEditingController _installationDateController = TextEditingController();
  final TextEditingController _commissioningDateController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  // Flags to indicate that the dates have been saved (and so the fields are locked).
  bool _isInstallationDateLocked = false;
  bool _isCommissioningDateLocked = false;

  @override
  void initState() {
    super.initState();
    // If the PSA document already has dates, lock those fields.
    if (widget.psaData.containsKey('installationDate') &&
        widget.psaData['installationDate'] != null) {
      _isInstallationDateLocked = true;
      _installationDateController.text = DateFormat('yyyy-MM-dd').format(
          (widget.psaData['installationDate'] as Timestamp).toDate());
    }
    if (widget.psaData.containsKey('commissioningDate') &&
        widget.psaData['commissioningDate'] != null) {
      _isCommissioningDateLocked = true;
      _commissioningDateController.text = DateFormat('yyyy-MM-dd').format(
          (widget.psaData['commissioningDate'] as Timestamp).toDate());
    }
    // Fetch PSA details and check equipment linking.
    _fetchPSADetails().then((_) {
      _checkAllEquipmentLinked();
    });
  }

  /// Fetch details (project, lot, site) from the PSA document.
  Future<void> _fetchPSADetails() async {
    try {
      String projectId = widget.psaData['projectId'] ?? "";
      String lotId = widget.psaData['lotId'] ?? "";
      String siteId = widget.psaData['siteId'] ?? "";

      if (projectId.isNotEmpty) {
        DocumentSnapshot projectSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();
        if (projectSnapshot.exists) {
          projectNumber = projectSnapshot['projectId'].toString();
        }
      }

      if (lotId.isNotEmpty) {
        DocumentSnapshot lotSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('lots')
            .doc(lotId)
            .get();
        if (lotSnapshot.exists) {
          lotName = lotSnapshot['lotName'] ?? "Unknown Lot";
        }
      }

      if (siteId.isNotEmpty) {
        DocumentSnapshot siteSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .collection('lots')
            .doc(lotId)
            .collection('sites')
            .doc(siteId)
            .get();
        if (siteSnapshot.exists) {
          siteName = siteSnapshot['siteName'] ?? "Unknown Site";
        }
      }

      // Determine number of lines from the "lineReferences" field.
      if (widget.psaData.containsKey('lineReferences') &&
          widget.psaData['lineReferences'] is Map) {
        Map lineRefs = widget.psaData['lineReferences'];
        numLines = lineRefs.length;
      }
      // Initialize equipment selection map for each line.
      for (int line = 1; line <= numLines; line++) {
        if (!selectedEquipmentByLine.containsKey(line)) {
          Map<String, String?> equipmentMap = {};
          // Initialize all equipment types as null.
          for (String type in _allEquipmentTypes()) {
            equipmentMap[type] = null;
          }
          selectedEquipmentByLine[line] = equipmentMap;
        }
      }

      setState(() {});
    } catch (e) {
      print("Error fetching PSA details: $e");
    }
  }

  /// Return a list of all equipment types.
  List<String> _allEquipmentTypes() {
    return [
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
  }

  /// Return a set of equipment types for which "Not Concerned" should be offered.
  Set<String> _notConcernedTypes() {
    return {
      "Room",
      "Container",
      "Skid",
      "Dryer",
      "Booster",
      "Filling Ramp",
      "Backup Ramp",
      "MGPS"
    };
  }

  /// Check that every line has all required equipment linked.
  Future<void> _checkAllEquipmentLinked() async {
    // Query all documents in the PSA subcollection.
    QuerySnapshot linkedEquipmentSnapshot = await FirebaseFirestore.instance
        .collection('psa_units')
        .doc(widget.psaId)
        .collection('PSA_linked_equipment_list')
        .get();

    // Build a set of keys in the format "line{lineNumber}_{equipmentType}".
    Set<String> keys = linkedEquipmentSnapshot.docs.map((doc) => doc.id as String).toSet();

    print("DEBUG: numLines = $numLines");
    print("DEBUG: Keys in PSA_linked_equipment_list: $keys");

    // Define the required equipment types.
    List<String> requiredEquipment = _allEquipmentTypes();

    bool allLinked = true;
    // Check for every line.
    for (int i = 1; i <= numLines; i++) {
      for (String equip in requiredEquipment) {
        String expectedKey = "line${i}_$equip";
        print("DEBUG: Checking expected key: $expectedKey");
        if (!keys.contains(expectedKey)) {
          allLinked = false;
          print("DEBUG: Missing key: $expectedKey");
          break;
        }
      }
      if (!allLinked) break;
    }

    print("DEBUG: allLinked = $allLinked");
    setState(() {
      allEquipmentAdded = allLinked;
    });
  }

  /// Save installation and commissioning dates.
  /// After saving, a dialog is shown. When the user taps "OK," the date fields are locked (greyed)
  /// and then the page is closed.
  Future<void> _saveInstallationAndCommissioningDates() async {
    if (!allEquipmentAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please link all equipment before setting the dates."),
        ),
      );
      return;
    }

    try {
      Timestamp? installationTs = _installationDateController.text.isNotEmpty
          ? Timestamp.fromDate(DateFormat('yyyy-MM-dd')
          .parse(_installationDateController.text))
          : null;
      Timestamp? commissioningTs = _commissioningDateController.text.isNotEmpty
          ? Timestamp.fromDate(DateFormat('yyyy-MM-dd')
          .parse(_commissioningDateController.text))
          : null;

      String newStatus = "Not Installed Yet";
      if (installationTs != null) {
        newStatus = "Installed and Functional";
      }

      // Update the PSA document.
      await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(widget.psaId)
          .update({
        'installationDate': installationTs,
        'commissioningDate': commissioningTs,
        'status': newStatus,
      });

      // Update linked equipment documents in a batch.
      WriteBatch batch = FirebaseFirestore.instance.batch();
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(widget.psaId)
          .collection('PSA_linked_equipment_list')
          .get();

      for (var doc in snapshot.docs) {
        var equipmentData = doc.data() as Map<String, dynamic>;
        String? equipId = equipmentData['equipmentId'];
        if (equipId != null && equipId != "Not Concerned" && equipId.isNotEmpty) {
          DocumentReference equipRef =
          FirebaseFirestore.instance.collection('equipment').doc(equipId);
          batch.update(equipRef, {
            'installedDate': installationTs,
            'commissioningDate': commissioningTs,
          });
        }
      }
      await batch.commit();

      // Show a dialog indicating that the PSA was installed and commissioned successfully.
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Success"),
            content: const Text("PSA installed and commissioned successfully."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog.
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );

      // Lock the date fields so they become disabled (greyed out).
      setState(() {
        _isInstallationDateLocked = true;
        _isCommissioningDateLocked = true;
      });
      // Close the Edit PSA page.
      Navigator.pop(context);
    } catch (e) {
      print("Error updating dates: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error updating dates")));
    }
  }


  /// Adds a new comment to the PSA unit and updates the parent PSA document with the latest comment timestamp.
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      String authorName = "Unknown";
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String firstName = userData['firstName'] ?? "";
        String lastName = userData['lastName'] ?? "";
        authorName = "$firstName $lastName".trim();
        if (authorName.isEmpty) {
          authorName = "Unknown";
        }
      }
      // Add the comment to the comments subcollection.
      await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(widget.psaId)
          .collection('comments')
          .add({
        'authorId': currentUserId,
        'authorName': authorName,
        'comment': _commentController.text.trim(),
        'timestamp': Timestamp.now(),
      });
      // Also update the parent PSA document with the lastCommentTimestamp.
      await FirebaseFirestore.instance
          .collection('psa_units')
          .doc(widget.psaId)
          .update({'lastCommentTimestamp': Timestamp.now()});
      _commentController.clear();
    } catch (e) {
      print("Error adding comment: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error adding comment")));
    }
  }

  /// Helper widget to build a date field.
  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required bool locked,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.calendar_today),
        fillColor: locked ? Colors.grey[300] : null,
        filled: locked,
      ),
      readOnly: true,
      enabled: !locked,
      onTap: !locked
          ? () async {
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) {
          setState(() {
            controller.text = DateFormat('yyyy-MM-dd').format(pickedDate);
          });
        }
      }
          : null,
    );
  }

  /// Build the comments list.
  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('psa_units')
          .doc(widget.psaId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No comments yet.");
        }
        final commentDocs = snapshot.data!.docs;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: commentDocs.length,
          separatorBuilder: (context, index) =>
          const Divider(height: 1, color: Colors.grey),
          itemBuilder: (context, index) {
            var data = commentDocs[index].data() as Map<String, dynamic>;
            String commentText = data['comment'] ?? "";
            String authorName = data['authorName'] ?? "Unknown";
            DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
            String formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
            return ListTile(
              title: Text(commentText),
              subtitle: Text("By $authorName"),
              trailing: Text(
                formattedTime,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dates are editable only if not locked and all equipment are linked.
    bool datesEditable = !_isInstallationDateLocked &&
        !_isCommissioningDateLocked &&
        allEquipmentAdded;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit PSA"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PSA Details Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PSA Reference: ${widget.psaData['reference'] ?? 'Not Assigned'}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.folder, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "Project Number: ${projectNumber ?? 'Unknown'}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.view_list, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "Lot: ${lotName ?? 'Unknown Lot'}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          "Site: ${siteName ?? 'Unknown Site'}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Equipment Linking Warning
            if (!allEquipmentAdded)
              Card(
                color: Colors.red[50],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: const [
                      Icon(Icons.warning, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Please link all equipment before setting the dates.",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Date Fields Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Set Dates",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildDateField(
                        label: "Installation Date",
                        controller: _installationDateController,
                        locked: _isInstallationDateLocked || !allEquipmentAdded),
                    const SizedBox(height: 16),
                    _buildDateField(
                        label: "Commissioning Date",
                        controller: _commissioningDateController,
                        locked: _isCommissioningDateLocked || !allEquipmentAdded),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: datesEditable ? _saveInstallationAndCommissioningDates : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: datesEditable ? const Color(0xFF003366) : Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        child: const Text("Save Dates"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Comments Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Comments",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        labelText: "Add Comment",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: _addComment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        child: const Text("Add Comment"),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      "Recent Comments",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildCommentsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
