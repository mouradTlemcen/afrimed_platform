import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher.dart';

import 'add_shipment_ticket_page.dart';
import 'progress_details_page.dart';
// Test shipment progress page for demonstration.
import 'shipment_progress_page.dart';

class ShipmentProgressPage extends StatefulWidget {
  final String shipmentTicketId;
  const ShipmentProgressPage({Key? key, required this.shipmentTicketId}) : super(key: key);

  @override
  _ShipmentProgressPageState createState() => _ShipmentProgressPageState();
}

class _ShipmentProgressPageState extends State<ShipmentProgressPage> {
  // New: For status update.
  String? _selectedNewStatus;
  final List<String> _statusOptions = [
    "shipment initiated",
    "maritime shipment",
    "flight shipment",
    "land shipment"
  ];

  // For adding a new progress update.
  TextEditingController progressTextController = TextEditingController();
  File? _progressImageFile;       // Mobile usage.
  XFile? _pickedProgressXFile;      // Web usage.
  bool _isUploadingImage = false;
  String? _progressImageUrl;

  // For final report upload.
  bool _needReport = false;
  File? _reportFile;
  PlatformFile? _reportPlatformFile;
  bool _isUploadingReportFile = false;
  String? _reportFileUrl;

  @override
  void initState() {
    super.initState();
    // No additional initialization needed here.
  }

  // ----- NEW: Update shipment status.
  Future<void> _updateShipmentStatus(String newStatus) async {
    try {
      DocumentReference ticketRef = FirebaseFirestore.instance
          .collection("shipment_tickets")
          .doc(widget.shipmentTicketId);
      await ticketRef.update({
        "shipmentStatus": newStatus,
        "shipmentStatusHistory": FieldValue.arrayUnion([
          {"status": newStatus, "changedAt": Timestamp.now()}
        ])
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Shipment status updated to '$newStatus'")));
    } catch (e) {
      debugPrint("Error updating shipment status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating status: $e"), backgroundColor: Colors.red));
    }
  }

  // ----- PICK & UPLOAD PROGRESS IMAGE -----
  Future<void> _pickProgressImage() async {
    try {
      final picker = ImagePicker();
      _pickedProgressXFile = await picker.pickImage(source: ImageSource.gallery);
      if (_pickedProgressXFile != null) {
        setState(() {
          _progressImageFile = File(_pickedProgressXFile!.path);
        });
      }
    } catch (e) {
      debugPrint("Error picking progress image: $e");
    }
  }

  Future<void> _uploadProgressImage() async {
    if (_progressImageFile == null && _pickedProgressXFile == null) return;
    setState(() {
      _isUploadingImage = true;
    });
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString() +
          "_" +
          (p.basename(_pickedProgressXFile!.path));
      final ref = FirebaseStorage.instance
          .ref()
          .child("shipmentProgressImages")
          .child(widget.shipmentTicketId)
          .child(fileName);
      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await _pickedProgressXFile!.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        uploadTask = ref.putFile(_progressImageFile!);
      }
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        _progressImageUrl = downloadUrl;
      });
    } catch (e) {
      debugPrint("Error uploading progress image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error uploading image: $e")));
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  // ----- Submit a new shipment progress update -----
  Future<void> _submitProgressUpdate() async {
    String progressText = progressTextController.text.trim();
    if (progressText.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Please enter progress details")));
      return;
    }
    if (_progressImageFile != null || _pickedProgressXFile != null) {
      await _uploadProgressImage();
    }
    Timestamp now = Timestamp.now();
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "Unknown";
    Map<String, dynamic> progressData = {
      'text': progressText,
      'timestamp': now,
      'userId': currentUserId,
    };
    if (_progressImageUrl != null) {
      progressData['pictureUrl'] = _progressImageUrl;
    }
    try {
      await FirebaseFirestore.instance
          .collection("shipment_tickets")
          .doc(widget.shipmentTicketId)
          .collection("progress")
          .add(progressData);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Progress update added.")));
      progressTextController.clear();
      setState(() {
        _progressImageFile = null;
        _pickedProgressXFile = null;
        _progressImageUrl = null;
      });
    } catch (e) {
      debugPrint("Error adding progress update: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // ----- Helper: Download Report File (existing function, do not duplicate) -----
  Future<void> _downloadReportFile() async {
    if (_reportFileUrl == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("No report file available")));
      return;
    }
    if (kIsWeb) {
      html.window.open(_reportFileUrl!, "_blank");
    } else {
      final reportUrl = _reportFileUrl!;
      if (await canLaunch(reportUrl)) {
        await launch(reportUrl);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Cannot open report file")));
      }
    }
  }

  // ----- Helper: Download All Progress as PDF (existing function) -----
  Future<void> _downloadAllProgressAsPdf() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('shipment_tickets')
          .doc(widget.shipmentTicketId)
          .collection('progress')
          .orderBy('timestamp', descending: false)
          .get();
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No progress to download.")),
        );
        return;
      }
      final pdfDoc = pw.Document();
      List<pw.Widget> progressWidgets = [];
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp ts = data['timestamp'];
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
        String progressText = data['text'] ?? "";
        bool afterDone = data['afterTaskDone'] == true;
        if (afterDone) {
          progressText += " (added after completion)";
        }
        String userId = data['userId'] ?? "Unknown";
        String? picUrl = data['pictureUrl'];
        String userName = await _getUserName(userId);
        Uint8List? picData;
        if (picUrl != null) {
          try {
            final response = await http.get(Uri.parse(picUrl));
            if (response.statusCode == 200) {
              picData = response.bodyBytes;
            }
          } catch (e) {
            debugPrint("Error fetching image: $e");
          }
        }
        progressWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Date: $dateStr", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text("Written by: $userName"),
                pw.Text("Progress: $progressText"),
                if (picData != null)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Image(pw.MemoryImage(picData), width: 200),
                  ),
                pw.Divider(),
              ],
            ),
          ),
        );
      }
      pdfDoc.addPage(
        pw.MultiPage(build: (pw.Context context) => progressWidgets),
      );
      final pdfBytes = await pdfDoc.save();
      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = "shipment_${widget.shipmentTicketId}_progress.pdf";
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF download is implemented for web. On mobile, implement local saving.")),
        );
      }
    } catch (e) {
      debugPrint("Error downloading progress as PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error downloading progress as PDF: $e")),
      );
    }
  }

  /// Helper: Fetch a user's full name from Firestore.
  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty || userId == "Unknown") {
      String? currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) {
        userId = currentUid;
      }
    }
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        String firstName = data["firstName"] ?? "";
        String lastName = data["lastName"] ?? "";
        return "$firstName $lastName".trim();
      } else {
        return userId;
      }
    } catch (e) {
      return userId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Shipment Progress"),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("shipment_tickets")
              .doc(widget.shipmentTicketId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || !snapshot.data!.exists)
              return Center(child: Text("Shipment ticket not found."));

            // Load shipment ticket data.
            Map<String, dynamic> ticketData = snapshot.data!.data() as Map<String, dynamic>;

            // --- New Header: If the shipment is related to a curative ticket,
            // fetch the curative maintenance ticket details.
            Widget curativeHeader = Container();
            if (ticketData.containsKey("curativeMaintenanceTicketId") &&
                ticketData["curativeMaintenanceTicketId"] != null) {
              curativeHeader = FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("curative_maintenance_tickets")
                    .doc(ticketData["curativeMaintenanceTicketId"])
                    .get(),
                builder: (context, curativeSnapshot) {
                  if (curativeSnapshot.connectionState == ConnectionState.waiting) {
                    return LinearProgressIndicator();
                  }
                  if (!curativeSnapshot.hasData || !curativeSnapshot.data!.exists) {
                    return Text("Curative Ticket not found.", style: TextStyle(color: Colors.red));
                  }
                  Map<String, dynamic> curativeData = curativeSnapshot.data!.data() as Map<String, dynamic>;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Project: ${curativeData['projectNumber'] ?? curativeData['Afrimed_projectId'] ?? 'N/A'}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("Site: ${curativeData['siteName'] ?? 'N/A'}", style: TextStyle(fontSize: 16)),
                      Text("Line: ${curativeData['line'] ?? 'N/A'}", style: TextStyle(fontSize: 16)),
                      Text("Equipment: ${curativeData['equipmentName'] ?? 'N/A'}", style: TextStyle(fontSize: 16)),
                      Text("Spare Part: ${curativeData['selectedSparePart'] ?? 'N/A'}", style: TextStyle(fontSize: 16)),
                      Divider(),
                    ],
                  );
                },
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show the curative ticket details header if available.
                  curativeHeader,
                  // Shipment details header.
                  Text("Shipment Reference: ${ticketData['shipmentReference'] ?? ''}",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Status: ${ticketData['shipmentStatus'] ?? 'Unknown'}",
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 4),
                  Text("Origin: ${ticketData['origin'] ?? ''}", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 4),
                  Text("Destination: ${ticketData['destination'] ?? ''}", style: TextStyle(fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                    "Shipment Date: ${ticketData['shipmentDate'] != null ? DateFormat('yyyy-MM-dd').format((ticketData['shipmentDate'] as Timestamp).toDate()) : '-'}",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Expected Arrival: ${ticketData['expectedArrivalDate'] != null ? DateFormat('yyyy-MM-dd').format((ticketData['expectedArrivalDate'] as Timestamp).toDate()) : '-'}",
                    style: TextStyle(fontSize: 16),
                  ),
                  Divider(height: 24),
                  // Shipment Status Update Section.
                  Text("Update Shipment Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: "New Shipment Status"),
                    items: _statusOptions.map((status) {
                      return DropdownMenuItem<String>(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedNewStatus = value;
                      });
                    },
                    validator: (val) => val == null || val.isEmpty ? "Select new status" : null,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _selectedNewStatus == null ? null : () => _updateShipmentStatus(_selectedNewStatus!),
                    child: Text("Update Shipment Status"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  ),
                  Divider(height: 24),
                  // Display Shipment Status History.
                  Text("Shipment Status History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Builder(
                    builder: (context) {
                      List<dynamic> statusHistory = [];
                      if (ticketData.containsKey("shipmentStatusHistory") &&
                          ticketData["shipmentStatusHistory"] is List) {
                        statusHistory = ticketData["shipmentStatusHistory"];
                      }
                      if (statusHistory.isEmpty) {
                        return Text("No status history available.");
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: statusHistory.length,
                        itemBuilder: (context, index) {
                          var entry = statusHistory[index];
                          String histStatus = entry["status"] ?? "Unknown";
                          Timestamp? ts = entry["changedAt"];
                          String changedAt = ts != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                              : "Unknown date";
                          return ListTile(
                            title: Text(histStatus),
                            subtitle: Text("Changed at: $changedAt"),
                          );
                        },
                      );
                    },
                  ),
                  Divider(height: 24),
                  // Progress Updates Section.
                  Text("Progress Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("shipment_tickets")
                        .doc(widget.shipmentTicketId)
                        .collection("progress")
                        .orderBy("timestamp", descending: true)
                        .snapshots(),
                    builder: (context, progSnapshot) {
                      if (progSnapshot.connectionState == ConnectionState.waiting)
                        return Center(child: CircularProgressIndicator());
                      if (!progSnapshot.hasData || progSnapshot.data!.docs.isEmpty)
                        return Text("No progress updates yet.");
                      List<QueryDocumentSnapshot> progressDocs = progSnapshot.data!.docs;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: progressDocs.length,
                        itemBuilder: (context, index) {
                          var progressData = progressDocs[index].data() as Map<String, dynamic>;
                          Timestamp ts = progressData["timestamp"];
                          String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(progressData["text"] ?? ""),
                              subtitle: Text(dateStr),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Divider(height: 24),
                  // Section to add a new progress update.
                  Text("Add New Progress Update", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: progressTextController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter progress details",
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickProgressImage,
                        icon: Icon(Icons.image),
                        label: Text("Attach Picture"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                      SizedBox(width: 16),
                      if (_progressImageFile != null)
                        Text("Image Selected", style: TextStyle(color: Colors.green)),
                    ],
                  ),
                  if (_isUploadingImage)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 8),
                          Text("Uploading image..."),
                        ],
                      ),
                    ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _submitProgressUpdate,
                    child: Text("Submit Progress Update"),
                  ),
                  Divider(height: 24),
                  // Report download section if task is completed.
                  if (ticketData["shipmentStatus"] == "Done In Time" || ticketData["shipmentStatus"] == "Done After Deadline")
                    if (_reportFileUrl != null)
                      ElevatedButton.icon(
                        onPressed: _downloadReportFile,
                        icon: Icon(Icons.download),
                        label: Text("Download Report File"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      ),
                  // Button to download progress as PDF.
                  ElevatedButton.icon(
                    onPressed: _downloadAllProgressAsPdf,
                    icon: Icon(Icons.download),
                    label: Text("Download All Progress (PDF)"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
