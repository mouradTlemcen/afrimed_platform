import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SparePartReplacementPage extends StatefulWidget {
  final String equipmentId; // The real doc ID from the equipment collection
  const SparePartReplacementPage({Key? key, required this.equipmentId}) : super(key: key);

  @override
  _SparePartReplacementPageState createState() => _SparePartReplacementPageState();
}

class _SparePartReplacementPageState extends State<SparePartReplacementPage> {
  // List of spare parts from the equipment document's subcollection.
  List<Map<String, dynamic>> sparePartsList = [];
  String? selectedSparePartDocId;
  int? selectedSparePartIndex;

  // Controllers for new spare part details.
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController serialController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSpareParts();
  }

  /// Loads the spare parts from the equipment's subcollection.
  Future<void> _loadSpareParts() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(widget.equipmentId)
          .collection('spareParts')
          .get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          errorMessage = "No spare parts found for this equipment.";
          sparePartsList = [];
        });
      } else {
        sparePartsList = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          return {
            "docId": doc.id,
            "type": data['type'] ?? "Unnamed",
            "brand": data['brand'] ?? "",
            "model": data['model'] ?? "",
            "serial": data['serialNumber'] ?? "",
          };
        }).toList();
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error loading spare parts: $e";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Builds a display name for a spare part.
  String _buildDisplayName(Map<String, dynamic> part) {
    String displayName = part['type'];
    if ((part['brand'] as String).isNotEmpty || (part['model'] as String).isNotEmpty) {
      displayName += " (${part['brand']}-${part['model']})";
    }
    return displayName;
  }

  /// Called when the user selects a spare part from the dropdown.
  void _onSparePartSelected(String? selectedValue) {
    for (int i = 0; i < sparePartsList.length; i++) {
      var part = sparePartsList[i];
      String displayName = _buildDisplayName(part);
      if (displayName == selectedValue) {
        setState(() {
          selectedSparePartIndex = i;
          selectedSparePartDocId = part['docId'];
          // Populate controllers with existing details.
          brandController.text = part['brand'];
          modelController.text = part['model'];
          serialController.text = part['serial'];
        });
        break;
      }
    }
  }

  /// Replaces the selected spare part with new details.
  Future<void> _replaceSparePart() async {
    if (selectedSparePartIndex == null || selectedSparePartDocId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please select a spare part to replace.")));
      return;
    }
    String newBrand = brandController.text.trim();
    String newModel = modelController.text.trim();
    String newSerial = serialController.text.trim();
    if (newBrand.isEmpty || newModel.isEmpty || newSerial.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please fill in all new details.")));
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      // Get current spare part details from the selected spare part document.
      DocumentReference sparePartRef = FirebaseFirestore.instance
          .collection('equipment')
          .doc(widget.equipmentId)
          .collection('spareParts')
          .doc(selectedSparePartDocId);
      DocumentSnapshot sparePartDoc = await sparePartRef.get();
      if (!sparePartDoc.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Selected spare part not found.")));
        return;
      }
      var oldData = sparePartDoc.data() as Map<String, dynamic>;

      // Append the old spare part details to the equipment document's history.
      DocumentReference eqRef = FirebaseFirestore.instance
          .collection('equipment')
          .doc(widget.equipmentId);
      DocumentSnapshot eqDoc = await eqRef.get();
      if (eqDoc.exists) {
        var eqData = eqDoc.data() as Map<String, dynamic>;
        List replacedHistory = eqData['replacedSpareParts'] ?? [];
        replacedHistory.add({
          "oldSparePart": oldData,
          "replacedAt": Timestamp.now(),
        });
        await eqRef.update({
          "replacedSpareParts": replacedHistory,
        });
      }

      // Update the selected spare part document with the new details.
      await sparePartRef.update({
        "brand": newBrand,
        "model": newModel,
        "serialNumber": newSerial,
        "lastUpdated": Timestamp.now(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Spare part replaced successfully.")));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error replacing spare part: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Replace Spare Part"),
        backgroundColor: Colors.deepOrange,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Select Spare Part to Replace",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (errorMessage != null)
              Text(errorMessage!, style: TextStyle(color: Colors.red))
            else if (sparePartsList.isEmpty)
              Text("No spare parts available for this equipment.")
            else
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: sparePartsList.map((part) {
                  return DropdownMenuItem<String>(
                    value: _buildDisplayName(part),
                    child: Text(_buildDisplayName(part)),
                  );
                }).toList(),
                onChanged: _onSparePartSelected,
                value: selectedSparePartIndex != null
                    ? _buildDisplayName(sparePartsList[selectedSparePartIndex!])
                    : null,
              ),
            SizedBox(height: 16),
            if (selectedSparePartIndex != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "New Spare Part Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  // Display spare part name (read-only)
                  TextFormField(
                    initialValue: sparePartsList[selectedSparePartIndex!]['type'],
                    decoration: InputDecoration(
                      labelText: "Spare Part Name",
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: brandController,
                    decoration: InputDecoration(
                      labelText: "Brand",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: modelController,
                    decoration: InputDecoration(
                      labelText: "Model",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: serialController,
                    decoration: InputDecoration(
                      labelText: "Serial Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _replaceSparePart,
                    child: Text("Replace Spare Part"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
