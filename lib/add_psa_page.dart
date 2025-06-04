/*
File: add_psa_page.dart
Description:
  This page allows users to add a PSA unit to a selected project, lot, and site.
  It fetches available projects, lots, and unlinked sites, and allows the user to specify
  the number of equipment lines and a reference for each line. Before showing the fields
  for equipment lines, the page checks if a PSA unit already exists for the selected project/lot/site.
  If one exists, a message is displayed and the user is prevented from adding another PSA.
*/

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddPSAPage extends StatefulWidget {
  @override
  _AddPSAPageState createState() => _AddPSAPageState();
}

class _AddPSAPageState extends State<AddPSAPage> {
  // Declare a form key.
  final _formKey = GlobalKey<FormState>();

  String? selectedProjectId;
  String? selectedProjectName;
  String? selectedLot;
  String? selectedLotName;
  String? selectedSite;
  String? selectedSiteName;
  String psaReference = '';

  // New: Number of equipment lines and controllers for each line's reference.
  int numberOfLines = 1;
  final List<TextEditingController> lineReferenceControllers = [];

  // Flag indicating if a PSA already exists for the selected site.
  bool _siteHasPSA = false;

  @override
  void initState() {
    super.initState();
    // Initialize with one controller.
    lineReferenceControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (var controller in lineReferenceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Fetch Lots for Selected Project.
  Future<List<Map<String, dynamic>>> fetchLotsForProject(String projectId) async {
    QuerySnapshot lotsSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .get();

    return lotsSnapshot.docs.map((lot) {
      var lotData = lot.data() as Map<String, dynamic>;
      return {'id': lot.id, 'lotName': lotData['lotName'] ?? 'Unnamed Lot'};
    }).toList();
  }

  /// Fetch Unlinked Sites for Selected Lot.
  Future<List<Map<String, dynamic>>> fetchUnlinkedSites(String projectId, String lotId) async {
    QuerySnapshot sitesSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .doc(lotId)
        .collection('sites')
        .where('isLinked', isEqualTo: false)
        .get();

    return sitesSnapshot.docs.map((site) {
      var siteData = site.data() as Map<String, dynamic>;
      return {'id': site.id, 'siteName': siteData['siteName'] ?? 'Unnamed Site'};
    }).toList();
  }

  /// Generate a base PSA Reference using project and site names.
  void _generatePSAReference() {
    setState(() {
      psaReference = "PSA_${selectedProjectName}_$selectedSiteName";
    });
  }

  /// Check if the selected project/lot/site already has a PSA.
  Future<bool> _hasPSAForSite(String projectId, String lotId, String siteId) async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('psa_units')
        .where('projectId', isEqualTo: projectId)
        .where('lotId', isEqualTo: lotId)
        .where('siteId', isEqualTo: siteId)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// When a site is selected, check if a PSA already exists.
  Future<void> _checkForExistingPSA() async {
    if (selectedProjectId != null && selectedLot != null && selectedSite != null) {
      bool exists = await _hasPSAForSite(selectedProjectId!, selectedLot!, selectedSite!);
      setState(() {
        _siteHasPSA = exists;
      });
    }
  }

  /// Save the PSA Unit.
  Future<void> _savePSA() async {
    // Debug prints for troubleshooting.
    print("selectedProjectId: $selectedProjectId");
    print("selectedLot: $selectedLot");
    print("selectedSite: $selectedSite");
    print("psaReference: $psaReference");
    for (int i = 0; i < numberOfLines; i++) {
      print("Line ${i + 1} Reference: ${lineReferenceControllers[i].text.trim()}");
    }

    if (selectedProjectId == null ||
        selectedLot == null ||
        selectedSite == null ||
        psaReference.isEmpty ||
        !(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields before saving.")),
      );
      return;
    }

    // Build the lineReferences map.
    Map<String, String> lineReferences = {};
    for (int i = 0; i < numberOfLines; i++) {
      lineReferences["line${i + 1}"] = lineReferenceControllers[i].text.trim();
    }

    try {
      // Save PSA Unit with default maintenance status field.
      await FirebaseFirestore.instance.collection('psa_units').add({
        'Afrimed_projectId': selectedProjectName,  // <-- Add this line
        'projectId': selectedProjectId,
        'lotId': selectedLot,
        'siteId': selectedSite,
        'reference': psaReference,
        'lineReferences': lineReferences,
        'createdAt': Timestamp.now(),
        'status': 'Not Installed Yet',
      });


      // Update the selected site's "Linked to PSA" field.
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(selectedProjectId)
          .collection('lots')
          .doc(selectedLot)
          .collection('sites')
          .doc(selectedSite)
          .update({
        'isLinked': true,
        'Linked to PSA': psaReference,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PSA Unit added and linked to site successfully.")),
      );

      Navigator.pop(context);
    } catch (e) {
      print("Error saving PSA Unit: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error saving PSA Unit")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add PSA'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Wrap all fields in a Form widget.
          child: ListView(
            children: [
              // Select Project
              const Text("Select Project",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('projects').get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();

                  var projects = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: selectedProjectId,
                    onChanged: (newValue) {
                      setState(() {
                        selectedProjectId = newValue;
                        // Use 'Afrimed_projectId' for the project name.
                        selectedProjectName = projects
                            .firstWhere((p) => p.id == newValue)
                            .get('Afrimed_projectId');
                        selectedLot = null;
                        selectedSite = null;
                        psaReference = '';
                        _siteHasPSA = false;
                      });
                    },
                    items: projects.map((project) {
                      var data = project.data() as Map<String, dynamic>;
                      return DropdownMenuItem<String>(
                        value: project.id,
                        child: Text(data['Afrimed_projectId'] ?? 'Unknown'),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Select a project" : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Select Lot
              const Text("Select Lot",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              selectedProjectId == null
                  ? const Text("Please select a project first.")
                  : FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchLotsForProject(selectedProjectId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  var lots = snapshot.data!;
                  if (lots.isEmpty) {
                    return const Text("No lots found.");
                  }

                  return DropdownButtonFormField<String>(
                    value: selectedLot,
                    onChanged: (newValue) {
                      setState(() {
                        selectedLot = newValue;
                        selectedLotName = lots
                            .firstWhere((l) => l['id'] == newValue)['lotName'];
                        selectedSite = null;
                        psaReference = '';
                        _siteHasPSA = false;
                      });
                    },
                    items: lots.map((lot) {
                      return DropdownMenuItem<String>(
                        value: lot['id'],
                        child: Text(lot['lotName']),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Select a lot" : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // Select Site (Only Show Non-Linked Sites)
              const Text("Select Site",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              selectedLot == null
                  ? const Text("Please select a lot first.")
                  : FutureBuilder<List<Map<String, dynamic>>>(
                future: fetchUnlinkedSites(selectedProjectId!, selectedLot!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  var sites = snapshot.data!;
                  if (sites.isEmpty) {
                    return const Text("No available (unlinked) sites.");
                  }

                  return DropdownButtonFormField<String>(
                    value: selectedSite,
                    onChanged: (newValue) async {
                      var selectedSiteData =
                      sites.firstWhere((s) => s['id'] == newValue);
                      setState(() {
                        selectedSite = newValue;
                        selectedSiteName = selectedSiteData['siteName'];
                        psaReference = '';
                      });
                      await _checkForExistingPSA();
                      if (!_siteHasPSA) {
                        _generatePSAReference();
                      }
                    },
                    items: sites.map((site) {
                      return DropdownMenuItem<String>(
                        value: site['id'],
                        child: Text(site['siteName']),
                      );
                    }).toList(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Select a site" : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              // If a PSA already exists for the selected site, display a message.
              if (selectedSite != null && _siteHasPSA)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    "This project/lot/site already has a PSA. You cannot add another one.",
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                )
              else ...[
                // Select Number of Equipment Lines
                const Text("Number of Equipment Lines",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: numberOfLines,
                  onChanged: (newValue) {
                    setState(() {
                      numberOfLines = newValue ?? 1;
                      // Adjust controllers list.
                      while (lineReferenceControllers.length < numberOfLines) {
                        lineReferenceControllers.add(TextEditingController());
                      }
                      while (lineReferenceControllers.length > numberOfLines) {
                        lineReferenceControllers.removeLast();
                      }
                    });
                  },
                  items: [1, 2, 3]
                      .map((n) => DropdownMenuItem<int>(
                    value: n,
                    child: Text(n.toString()),
                  ))
                      .toList(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),

                // Dynamic Line Reference Fields
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(numberOfLines, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextFormField(
                        controller: lineReferenceControllers[index],
                        decoration: InputDecoration(
                          labelText: "Line ${index + 1} Reference",
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Enter reference for line ${index + 1}";
                          }
                          return null;
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // PSA Reference (Auto-generated)
                const Text("PSA Reference",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: psaReference.isNotEmpty
                        ? psaReference
                        : "PSA Reference will be generated",
                  ),
                ),
                const SizedBox(height: 20),

                // Save PSA Button
                ElevatedButton(
                  onPressed: _savePSA,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Save PSA',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
