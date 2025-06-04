// File: global_obligatory_docs_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GlobalObligatoryDocsPage extends StatefulWidget {
  @override
  _GlobalObligatoryDocsPageState createState() => _GlobalObligatoryDocsPageState();
}

class _GlobalObligatoryDocsPageState extends State<GlobalObligatoryDocsPage> {
  List<Map<String, dynamic>> allDocs = [];
  bool isLoading = false;

  // The full static list of phases -> docTitles, for the user to pick from.
  // (No fallback or seeding logic will be performed.)
  final Map<String, List<String>> phaseDocsMap = {
    "Tender Preparation and submission": [
      "Tender Document / Bid Proposal",
      "Technical Specifications",
      "Financial Projections / Cost Estimate",
      "Company Profile",
      "Legal Certificates / Registrations",
      "Previous Project References",
      "Clarifications / Addendums",
    ],
    "Order preparation": [
      "Order Confirmation",
      "Purchase Order",
      "Delivery Schedule",
    ],
    "Factory test": [
      "Factory Test Report",
      "Quality Assurance Certificate",
    ],
    "Shipment": [
      "Shipping Document",
      "Bill of Lading",
    ],
    "Site preparation": [
      "Site Inspection Report",
      "Pre-Installation Checklist",
    ],
    "Installation and training": [
      "Warranty Document",
      "Service Agreement",
      "Installation Report",
      "Inventory",
      "Certifications",
      "Electrical Reports",
      "PPM",
      "Daily Records",
      "Curative Maintenance",
      "Authorised Operators",
      "Commissioning Report",
      "Training Record",
      "SOPs",
      "Factory Test",
      "Progress Follow",
      "Signed by Both Parties",
    ],
    "Commissioning": [
      "Commissioning Certificate",
      "Handover Document",
    ],
    "Warranty period": [
      "Warranty Claim Form",
      "Maintenance Schedule",
    ],
    "After warranty period": [
      "Post-Warranty Service Agreement",
      "Final Inspection Report",
    ],
  };

  @override
  void initState() {
    super.initState();
    _fetchExistingDocs();
  }

  /// Simply fetch all documents from "global_obligatory_documents",
  /// ordered by phase + docTitle. If none exist, user sees "No docs set."
  Future<void> _fetchExistingDocs() async {
    setState(() => isLoading = true);
    try {
      final collectionRef = FirebaseFirestore.instance
          .collection('global_obligatory_documents');
      final snapshot = await collectionRef
          .orderBy('phase')
          .orderBy('docTitle')
          .get();

      final docs = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'phase': data['phase'] ?? '',
          'docTitle': data['docTitle'] ?? '',
        };
      }).toList();

      setState(() {
        allDocs = docs;
      });
    } catch (e) {
      print("Error fetching docs: $e");
      setState(() {
        allDocs = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Group documents by phase for easy display.
  Map<String, List<Map<String, dynamic>>> _groupDocsByPhase() {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var doc in allDocs) {
      final phase = doc['phase'] as String? ?? 'Unknown';
      grouped[phase] = grouped[phase] ?? [];
      grouped[phase]!.add(doc);
    }
    return grouped;
  }

  /// Show a dialog to add a new doc to Firestore.
  void _showAddDocDialog() {
    String selectedPhase = phaseDocsMap.keys.first;
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add New Obligatory Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Phase"),
              value: selectedPhase,
              items: phaseDocsMap.keys.map((phase) {
                return DropdownMenuItem<String>(
                  value: phase,
                  child: Text(phase),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) selectedPhase = val;
              },
            ),
            SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Document Title",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final docTitle = titleController.text.trim();
              if (docTitle.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('global_obligatory_documents')
                    .add({
                  'phase': selectedPhase,
                  'docTitle': docTitle,
                });
                Navigator.pop(ctx);
                // Reload from Firestore
                _fetchExistingDocs();
              }
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  /// Show a dialog to edit an existing doc from Firestore.
  void _showEditDocDialog(String docId, String oldPhase, String oldTitle) {
    String selectedPhase = oldPhase;
    final titleController = TextEditingController(text: oldTitle);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Obligatory Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: "Phase"),
              value: selectedPhase,
              items: phaseDocsMap.keys.map((phase) {
                return DropdownMenuItem<String>(
                  value: phase,
                  child: Text(phase),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) selectedPhase = val;
              },
            ),
            SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: "Document Title",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && docId.isNotEmpty) {
                print("Updating doc $docId => phase=$selectedPhase, docTitle=$newTitle");
                await FirebaseFirestore.instance
                    .collection('global_obligatory_documents')
                    .doc(docId)
                    .update({
                  'phase': selectedPhase,
                  'docTitle': newTitle,
                });
                Navigator.pop(ctx);
                // Reload from Firestore
                _fetchExistingDocs();
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  /// Delete a doc from Firestore by docId.
  Future<void> _deleteDoc(String docId) async {
    try {
      print("Deleting docId=$docId");
      await FirebaseFirestore.instance
          .collection('global_obligatory_documents')
          .doc(docId)
          .delete();
      setState(() {
        allDocs.removeWhere((doc) => doc['id'] == docId);
      });
    } catch (e) {
      print("Error deleting doc: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsByPhase = _groupDocsByPhase();

    return Scaffold(
      appBar: AppBar(
        title: Text("Global Obligatory Documents"),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : docsByPhase.isEmpty
          ? Center(child: Text("No obligatory documents set."))
          : ListView(
        children: docsByPhase.entries.map((entry) {
          final phase = entry.key;
          final items = entry.value;
          return ExpansionTile(
            title: Text(
              phase,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: items.map((doc) {
              final docId = doc['id'] as String;
              final docTitle = doc['docTitle'] as String;
              return ListTile(
                title: Text(docTitle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        _showEditDocDialog(docId, phase, docTitle);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteDoc(docId),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocDialog,
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
      ),
    );
  }
}
