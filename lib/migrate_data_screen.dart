import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrateDataScreen extends StatefulWidget {
  const MigrateDataScreen({Key? key}) : super(key: key);

  @override
  _MigrateDataScreenState createState() => _MigrateDataScreenState();
}

class _MigrateDataScreenState extends State<MigrateDataScreen> {
  bool _isLoading = false;
  String _log = "";

  // For single-doc migration
  final TextEditingController _acquiredDocController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Migrate Data"),
        backgroundColor: Colors.brown,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ------------------------------------------------------
            // Migrate ALL from acquiredEquipment => acquired_equipments
            // ------------------------------------------------------
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Migrate from 'acquiredEquipment' to 'acquired_equipments' (no 'status' field)",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _migrateAllAcquiredEquipment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child:
                      const Text("Migrate ALL acquiredEquipment"),
                    ),
                    const SizedBox(height: 12),
                    // Single doc text field + button
                    TextField(
                      controller: _acquiredDocController,
                      decoration: const InputDecoration(
                        labelText: "Doc ID (acquiredEquipment)",
                        hintText: "Enter old doc ID",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final docId =
                        _acquiredDocController.text.trim();
                        if (docId.isEmpty) {
                          setState(() {
                            _log +=
                            "Please enter a doc ID for acquiredEquipment.\n";
                          });
                        } else {
                          _migrateOneAcquired(docId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child:
                      const Text("Migrate ONE Doc (Acquired)"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              "Migration Logs:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Container(
              height: 300,
              color: Colors.black12,
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(child: Text(_log)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------
  // MIGRATE ALL acquiredEquipment => acquired_equipments
  // ------------------------------------------------------
  Future<void> _migrateAllAcquiredEquipment() async {
    setState(() {
      _isLoading = true;
      _log = "Starting migration of ALL from 'acquiredEquipment'...\n";
    });

    try {
      final oldSnap = await FirebaseFirestore.instance
          .collection('acquiredEquipment')
          .get();

      _log += "Found ${oldSnap.size} docs in old collection.\n";

      for (final doc in oldSnap.docs) {
        final oldData = doc.data();
        final docId = doc.id;

        final newData = _transformAcquiredDoc(oldData);
        final newRef = FirebaseFirestore.instance
            .collection('acquired_equipments')
            .doc(docId);

        await newRef.set(newData);
        _log += "Migrated doc '$docId'\n";
        setState(() {});
      }

      _log += "Migration of ALL 'acquiredEquipment' completed.\n";
    } catch (e) {
      _log += "Error migrating all: $e\n";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ------------------------------------------------------
  // MIGRATE ONE acquiredEquipment => acquired_equipments
  // ------------------------------------------------------
  Future<void> _migrateOneAcquired(String docId) async {
    setState(() {
      _isLoading = true;
      _log = "Migrating ONE doc from 'acquiredEquipment': $docId\n";
    });

    try {
      final oldDocRef = FirebaseFirestore.instance
          .collection('acquiredEquipment')
          .doc(docId);
      final oldSnap = await oldDocRef.get();
      if (!oldSnap.exists) {
        _log += "Doc $docId does not exist in old 'acquiredEquipment'\n";
      } else {
        final oldData = oldSnap.data();
        final newData = _transformAcquiredDoc(oldData);

        final newRef = FirebaseFirestore.instance
            .collection('acquired_equipments')
            .doc(docId);

        await newRef.set(newData);

        _log += "Migrated single doc '$docId' successfully.\n";
      }
    } catch (e) {
      _log += "Error migrating doc $docId: $e\n";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Transform from old doc to the final structure, removing 'status'
  /// but keeping 'linkedStatus', 'installationDate', etc.
  /// rename "acquisitionDate" => "createdAt"
  /// rename "typeOfEquipment" => "equipmentType"
  Map<String, dynamic> _transformAcquiredDoc(Map<String, dynamic>? oldData) {
    if (oldData == null) return {};

    // parse date if old doc had "acquisitionDate" or "createdAt"
    final dynamic oldDate =
        oldData["acquisitionDate"] ?? oldData["createdAt"];
    Timestamp realCreatedAt;
    if (oldDate is Timestamp) {
      realCreatedAt = oldDate;
    } else if (oldDate is String) {
      final dt = DateTime.tryParse(oldDate);
      realCreatedAt = (dt != null) ? Timestamp.fromDate(dt) : Timestamp.now();
    } else {
      realCreatedAt = Timestamp.now();
    }

    return {
      // keep old brand, model, invoiceNumber, etc.
      "brand": oldData["brand"] ?? "",
      "createdAt": realCreatedAt,
      "deliveryNoteUrl": oldData["deliveryNoteUrl"] ?? "",
      "equipmentType":
      oldData["equipmentType"] ?? oldData["typeOfEquipment"] ?? "N/A",
      "invoiceNumber": oldData["invoiceNumber"] ?? "",
      "invoiceUrl": oldData["invoiceUrl"] ?? "",
      "model": oldData["model"] ?? "",
      "serialNumber": oldData["serialNumber"] ?? "",

      // keep new fields but remove the 'status' line
      "linkedStatus": oldData["linkedStatus"] ?? "Not linked to PSA",
      "installationDate": oldData["installationDate"] ?? "not installed yet",
      "commissioningDate": oldData["commissioningDate"] ?? "Not commissioned yet",
      "functionalStatus": oldData["functionalStatus"] ?? "Not working",
      "deliveryNoteNumber": oldData["deliveryNoteNumber"] ?? "",
    };
  }
}
