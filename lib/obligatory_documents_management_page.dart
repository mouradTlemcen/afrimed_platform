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

  // The complete static list of phases -> obligatory document titles.
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
    _fetchOrSeedGlobalDocs();
  }

  /// Fetch all documents from the "global_obligatory_documents" collection.
  /// If the collection is empty, seed it with our static list.
  Future<void> _fetchOrSeedGlobalDocs() async {
    setState(() {
      isLoading = true;
    });
    try {
      CollectionReference collectionRef =
      FirebaseFirestore.instance.collection('global_obligatory_documents');
      QuerySnapshot snapshot = await collectionRef.get();

      if (snapshot.docs.isEmpty) {
        await _seedAllPhases(collectionRef);
        // Re-query after seeding.
        snapshot = await collectionRef.get();
      }

      setState(() {
        allDocs = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'phase': data['phase'] ?? '',
            'docTitle': data['docTitle'] ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print("Error fetching global obligatory documents: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Seed the collection with the entire static list from phaseDocsMap.
  Future<void> _seedAllPhases(CollectionReference ref) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    phaseDocsMap.forEach((phase, docTitles) {
      for (String title in docTitles) {
        DocumentReference docRef = ref.doc();
        batch.set(docRef, {
          'phase': phase,
          'docTitle': title,
        });
      }
    });
    await batch.commit();
    print("Seeded global obligatory documents for all phases.");
  }

  /// Show a dialog to add a new obligatory document.
  void _showAddDocDialog() {
    String selectedPhase = phaseDocsMap.keys.first;
    TextEditingController titleController = TextEditingController();

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
                selectedPhase = val ?? phaseDocsMap.keys.first;
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String docTitle = titleController.text.trim();
              if (docTitle.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('global_obligatory_documents')
                    .add({
                  'phase': selectedPhase,
                  'docTitle': docTitle,
                });
                Navigator.of(ctx).pop();
                _fetchOrSeedGlobalDocs(); // Refresh list.
              }
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  /// Show a dialog to edit an existing obligatory document.
  void _showEditDocDialog(String docId, String oldPhase, String oldTitle) {
    String selectedPhase = oldPhase;
    TextEditingController titleController = TextEditingController(text: oldTitle);

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
                selectedPhase = val ?? oldPhase;
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('global_obligatory_documents')
                    .doc(docId)
                    .update({
                  'phase': selectedPhase,
                  'docTitle': newTitle,
                });
                Navigator.of(ctx).pop();
                _fetchOrSeedGlobalDocs(); // Refresh list.
              }
            },
            child: Text("Update"),
          ),
        ],
      ),
    );
  }

  /// Delete a document record from the collection.
  Future<void> _deleteDoc(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('global_obligatory_documents')
          .doc(docId)
          .delete();
      setState(() {
        allDocs.removeWhere((d) => d['id'] == docId);
      });
    } catch (e) {
      print("Error deleting document: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Global Obligatory Documents"),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : allDocs.isEmpty
          ? Center(child: Text("No obligatory documents set."))
          : ListView.builder(
        itemCount: allDocs.length,
        itemBuilder: (context, index) {
          final doc = allDocs[index];
          final docId = doc['id'] as String;
          final phase = doc['phase'] as String;
          final docTitle = doc['docTitle'] as String;
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              title: Text(docTitle),
              subtitle: Text("Phase: $phase"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Edit button
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.orange),
                    onPressed: () {
                      _showEditDocDialog(docId, phase, docTitle);
                    },
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDoc(docId),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDocDialog,
        backgroundColor: Colors.blue,
        child: Icon(Icons.add),
      ),
    );
  }
}
