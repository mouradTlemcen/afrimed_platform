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

// Project-specific imports
import 'add_shipment_ticket_page.dart';
import 'progress_details_page.dart';
import 'shipment_progress_page.dart';

class TaskProgressPage extends StatefulWidget {
  final String taskId;
  TaskProgressPage({required this.taskId});

  @override
  _TaskProgressPageState createState() => _TaskProgressPageState();
}

class _TaskProgressPageState extends State<TaskProgressPage> {
  // Controllers
  TextEditingController progressController = TextEditingController();
  TextEditingController _reportVersionNameController = TextEditingController();

  // Task fields
  DateTime? taskDeadline;
  String? currentStatus;
  String? taskType;
  String? shipmentTicketId;

  // Progress image
  File? _progressImageFile;
  XFile? _pickedProgressXFile;
  bool _isUploadingProgressImage = false;
  String? _progressImageUrl;

  // Report files (final versions)
  bool _needReport = false;
  File? _reportFile;
  PlatformFile? _reportPlatformFile;
  bool _isUploadingReportFile = false;
  String? _reportOriginalFileName;

  @override
  void initState() {
    super.initState();
    _loadTaskDetails();
  }

  /// Minimal loading of task details
  void _loadTaskDetails() async {
    try {
      DocumentSnapshot taskDoc = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .get();
      if (taskDoc.exists) {
        var data = taskDoc.data() as Map<String, dynamic>;
        setState(() {
          taskDeadline = data["endingDate"] != null
              ? (data["endingDate"] as Timestamp).toDate()
              : null;
          currentStatus = data["status"];
          taskType = data["taskType"] ?? "";
          shipmentTicketId = data["shipmentTicketId"];
        });
      }
    } catch (e) {
      debugPrint("Error loading task: $e");
    }
  }

  /// Fetch all task info (assigned to, etc.)
  Future<Map<String, dynamic>?> _fetchTaskAllInfo() async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection("tasks")
          .doc(widget.taskId)
          .get();
      if (!docSnap.exists) return null;

      final taskData = docSnap.data() as Map<String, dynamic>;
      final assignedToUid = taskData["assignedTo"] as String? ?? "";
      String assignedToName = "";
      if (assignedToUid.isNotEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection("users")
            .doc(assignedToUid)
            .get();
        if (userSnap.exists) {
          final uData = userSnap.data() as Map<String, dynamic>;
          final firstName = uData["firstName"] ?? "";
          final lastName = uData["lastName"] ?? "";
          assignedToName = "$firstName $lastName".trim();
        }
      }
      taskData["assignedToName"] =
      assignedToName.isEmpty ? "(Not assigned)" : assignedToName;

      return taskData;
    } catch (e) {
      debugPrint("Error fetching all task info: $e");
      return null;
    }
  }

  /// Mark task as completed
  void _markTaskCompleted() async {
    if (taskDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deadline is not set.")),
      );
      return;
    }
    DateTime now = DateTime.now();
    String newStatus = now.isBefore(taskDeadline!) || now.isAtSameMomentAs(taskDeadline!)
        ? "Done In Time"
        : "Done After Deadline";

    if (_needReport) {
      final versionsSnap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('reportVersions')
          .get();
      if (versionsSnap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please upload at least one version of the report.")),
        );
        return;
      }
    }

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .update({
      'status': newStatus,
      'actualEndingDate': Timestamp.now(),
    });

    setState(() {
      currentStatus = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Task marked as $newStatus.")),
    );
  }

  /// Build the header
  Widget _buildTaskHeader(Map<String, dynamic> taskData) {
    final title = taskData["title"] ?? "";
    final assignedToName = taskData["assignedToName"] ?? "(Not assigned)";
    final createdByName = taskData["createdByName"] ?? "";
    final description = taskData["description"] ?? "";
    final status = taskData["status"] ?? "";

    final createdAtTs = taskData["createdAt"] as Timestamp?;
    final createdAtStr = (createdAtTs != null)
        ? DateFormat('yyyy-MM-dd HH:mm').format(createdAtTs.toDate())
        : "(Unknown creation date)";

    final startTs = taskData["startingDate"] as Timestamp?;
    final startStr = (startTs != null)
        ? DateFormat('yyyy-MM-dd').format(startTs.toDate())
        : "(No start date)";
    final endTs = taskData["endingDate"] as Timestamp?;
    final endStr = (endTs != null)
        ? DateFormat('yyyy-MM-dd').format(endTs.toDate())
        : "(No end date)";
    final actualEndTs = taskData["actualEndingDate"] as Timestamp?;
    String actualEndStr = "";
    if (actualEndTs != null) {
      actualEndStr = DateFormat('yyyy-MM-dd HH:mm').format(actualEndTs.toDate());
    }

    return Card(
      elevation: 4,
      color: Colors.white70,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Title: $title",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Assigned to: $assignedToName"),
            Text("Created by: $createdByName"),
            Text("Created at: $createdAtStr"),
            const SizedBox(height: 8),
            Text("Description: $description"),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text("Start date: $startStr")),
                SizedBox(width: 20),
                Expanded(child: Text("Estimated end date: $endStr")),
              ],
            ),
            if (actualEndStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Task finished at: $actualEndStr",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text("Status: $status"),
          ],
        ),
      ),
    );
  }

  /// Pick progress image
  Future<void> _pickProgressImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      _pickedProgressXFile = await picker.pickImage(source: ImageSource.gallery);
      if (_pickedProgressXFile != null) {
        setState(() {
          _progressImageFile = File(_pickedProgressXFile!.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  /// Upload image
  Future<void> _uploadProgressImage() async {
    if (_progressImageFile == null && _pickedProgressXFile == null) return;
    setState(() {
      _isUploadingProgressImage = true;
    });
    try {
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_" + p.basename(_pickedProgressXFile!.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child("progressImages")
          .child(widget.taskId)
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
      print("Error uploading image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image upload error: $e")),
      );
    } finally {
      setState(() {
        _isUploadingProgressImage = false;
      });
    }
  }

  /// Add progress
  void _submitProgress() async {
    String progressText = progressController.text.trim();
    if (progressText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter progress details.")),
      );
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

    if (currentStatus == "Done In Time" || currentStatus == "Done After Deadline") {
      progressData['afterTaskDone'] = true;
    }
    if (_progressImageUrl != null) {
      progressData['pictureUrl'] = _progressImageUrl;
    }
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.taskId)
        .collection('progress')
        .add(progressData);

    DocumentReference taskRef =
    FirebaseFirestore.instance.collection('tasks').doc(widget.taskId);
    DocumentSnapshot taskDoc = await taskRef.get();
    var data = taskDoc.data() as Map<String, dynamic>;
    if (data["status"] == "Pending") {
      await taskRef.update({
        'status': "In Progress",
        'lastProgressAt': now,
      });
      currentStatus = "In Progress";
    } else if (data["status"] != "Done In Time" &&
        data["status"] != "Done After Deadline") {
      await taskRef.update({'lastProgressAt': now});
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Progress added.")),
    );
    progressController.clear();
    setState(() {
      _progressImageFile = null;
      _pickedProgressXFile = null;
      _progressImageUrl = null;
    });
    _loadTaskDetails();
  }

  /// Pick report file
  Future<void> _pickReportFile() async {
    try {
      if (kIsWeb) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
        if (result != null && result.files.isNotEmpty) {
          _reportPlatformFile = result.files.first;
          _reportOriginalFileName = result.files.first.name;
        }
      } else {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
        );
        if (result != null && result.files.isNotEmpty) {
          _reportPlatformFile = result.files.first;
          _reportFile = File(_reportPlatformFile!.path!);
          _reportOriginalFileName = result.files.first.name;
        }
      }
      setState(() {});
    } catch (e) {
      print("Error picking report file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking report file: $e")),
      );
    }
  }

  /// Upload new report version
  Future<void> _uploadNewReportVersion() async {
    if (_reportFile == null && _reportPlatformFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a file first.")),
      );
      return;
    }
    setState(() {
      _isUploadingReportFile = true;
    });

    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance
          .ref()
          .child("taskReports")
          .child(widget.taskId)
          .child(fileName);

      UploadTask uploadTask;
      if (kIsWeb && _reportPlatformFile != null) {
        final fileBytes = _reportPlatformFile!.bytes;
        if (fileBytes == null) throw Exception("No file bytes available");
        uploadTask = ref.putData(fileBytes);
      } else if (_reportFile != null) {
        uploadTask = ref.putFile(_reportFile!);
      } else {
        throw Exception("No file selected");
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      String? originalFileName = _reportOriginalFileName;
      if (originalFileName == null || originalFileName.isEmpty) {
        if (_reportPlatformFile != null) {
          originalFileName = _reportPlatformFile!.name;
        } else if (_reportFile != null) {
          originalFileName = p.basename(_reportFile!.path);
        } else {
          originalFileName = "report_${DateTime.now().millisecondsSinceEpoch}";
        }
      }

      String versionName = _reportVersionNameController.text.trim();
      if (versionName.isEmpty) {
        versionName = "Version ${DateTime.now().toString().split('.')[0]}";
      }

      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('reportVersions')
          .add({
        "versionName": versionName,
        "reportUrl": downloadUrl,
        "storagePath": ref.fullPath,
        "timestamp": Timestamp.now(),
        "uploadedBy": FirebaseAuth.instance.currentUser?.uid ?? "Unknown",
        "originalFileName": originalFileName,
      });

      _reportFile = null;
      _reportPlatformFile = null;
      _reportOriginalFileName = null;
      _reportVersionNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Version '$versionName' uploaded.")),
      );
    } catch (e) {
      print("Error uploading report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload error: $e")),
      );
    } finally {
      setState(() {
        _isUploadingReportFile = false;
      });
    }
  }

  /// Download report (using original file name)
  Future<void> _downloadSpecificReport(String reportUrl, String fileName) async {
    if (kIsWeb) {
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = reportUrl
        ..style.display = 'none'
        ..download = fileName;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
    } else {
      if (await canLaunch(reportUrl)) {
        await launch(reportUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to open file.")),
        );
      }
    }
  }

  /// Confirm deletion without password
  void _confirmDeleteVersion(String docId, String storagePath) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Delete report version"),
          content: Text("Are you sure you want to delete this version?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text("Delete"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _deleteReportVersion(docId, storagePath);
    }
  }

  /// Delete reportVersion doc and file in storage
  Future<void> _deleteReportVersion(String docId, String storagePath) async {
    try {
      await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('reportVersions')
          .doc(docId)
          .delete();

      await FirebaseStorage.instance.ref(storagePath).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Version deleted successfully.")),
      );
    } catch (e) {
      print("Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete error: $e")),
      );
    }
  }

  /// Get full user name
  Future<String> _getUserName(String userId) async {
    if (userId.isEmpty || userId == "Unknown") {
      String? currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid != null) userId = currentUid;
    }
    try {
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
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

  /// Export all progress as PDF (web only)
  Future<void> _downloadAllProgressAsPdf() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.taskId)
          .collection('progress')
          .orderBy('timestamp', descending: false)
          .get();
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No progress to export.")),
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
          progressText += " (after completion)";
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
            print("Error fetching image: $e");
          }
        }

        progressWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Date: $dateStr",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
        pw.MultiPage(
          build: (pw.Context context) => progressWidgets,
        ),
      );
      final pdfBytes = await pdfDoc.save();

      if (kIsWeb) {
        final blob = html.Blob([pdfBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = "task_${widget.taskId}_progress.pdf";
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF export is implemented for web only."),
          ),
        );
      }
    } catch (e) {
      print("PDF export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("PDF export error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isTaskCompleted =
        currentStatus == "Done In Time" || currentStatus == "Done After Deadline";

    return Scaffold(
      appBar: AppBar(
        title: Text("Task Progress"),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 1) Header
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchTaskAllInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading task details...");
                } else if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}");
                }
                final taskData = snapshot.data;
                if (taskData == null) {
                  return const Text(
                    "No data found.",
                    style: TextStyle(color: Colors.red),
                  );
                }
                return _buildTaskHeader(taskData);
              },
            ),

            // 2) For curative maintenance
            if (taskType == "Curative maintenance") ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddShipmentTicketPage(curativeTicketId: widget.taskId),
                    ),
                  );
                },
                child: Text("Start Shipment Process"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              ),
              SizedBox(height: 8),
              if (shipmentTicketId == null)
                Text(
                  "No shipment ticket available.",
                  style: TextStyle(color: Colors.red),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ShipmentProgressPage(
                          shipmentTicketId: shipmentTicketId!,
                        ),
                      ),
                    );
                  },
                  child: Text("Track/Update Shipment"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              SizedBox(height: 16),
            ],

            // 3) Card to add progress
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add Progress",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    TextField(
                      controller: progressController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Progress details",
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickProgressImage,
                          icon: Icon(Icons.image),
                          label: Text("Choose image"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                        SizedBox(width: 16),
                        if (_progressImageFile != null || _pickedProgressXFile != null)
                          Text("Image selected", style: TextStyle(color: Colors.green)),
                      ],
                    ),
                    if (_isUploadingProgressImage)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 8),
                            Text("Uploading..."),
                          ],
                        ),
                      ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _submitProgress,
                      child: Text("Submit"),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // 4) Card to complete the task + report versions
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Complete Task",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _needReport,
                          onChanged: isTaskCompleted
                              ? null
                              : (bool? value) {
                            setState(() {
                              _needReport = value ?? false;
                            });
                          },
                        ),
                        Text("Requires final report? (multiple versions)"),
                      ],
                    ),

                    if (_needReport) ...[
                      SizedBox(height: 8),
                      TextField(
                        controller: _reportVersionNameController,
                        decoration: InputDecoration(
                          labelText: "Version name",
                          hintText: "e.g. 'v1.0' or 'Revision 2'",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: isTaskCompleted ? null : _pickReportFile,
                        icon: Icon(Icons.upload_file),
                        label: Text("Choose File"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      ),
                      if (_isUploadingReportFile)
                        Row(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(width: 8),
                            Text("Uploading..."),
                          ],
                        ),
                      if ((_reportFile != null || _reportPlatformFile != null) &&
                          !_isUploadingReportFile)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: isTaskCompleted ? null : _uploadNewReportVersion,
                            icon: Icon(Icons.cloud_upload),
                            label: Text("Upload this version"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),

                      SizedBox(height: 16),
                      Text("Report Versions:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tasks')
                            .doc(widget.taskId)
                            .collection('reportVersions')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Text("Loading...");
                          }
                          var docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return Text("No versions uploaded.");
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var doc = docs[index];
                              var data = doc.data() as Map<String, dynamic>;
                              String versionName = data["versionName"] ?? "(No name)";
                              String reportUrl = data["reportUrl"] ?? "";
                              String storagePath = data["storagePath"] ?? "";
                              Timestamp ts = data["timestamp"];
                              String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
                              String originalFileName = data["originalFileName"] ?? "report.pdf";

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  title: Text(versionName),
                                  subtitle: Text("Uploaded at: $dateStr"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.download),
                                        tooltip: "Download",
                                        onPressed: () => _downloadSpecificReport(reportUrl, originalFileName),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red),
                                        tooltip: "Delete",
                                        onPressed: () => _confirmDeleteVersion(
                                          doc.id,
                                          storagePath,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],

                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isTaskCompleted ? null : _markTaskCompleted,
                      child: Text(
                        isTaskCompleted
                            ? "Task Already Completed"
                            : "Mark Task as Completed",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // 5) PDF button
            ElevatedButton.icon(
              onPressed: _downloadAllProgressAsPdf,
              icon: Icon(Icons.download),
              label: Text("Download all progress (PDF)"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
            SizedBox(height: 16),

            // 6) Progress table
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tasks')
                  .doc(widget.taskId)
                  .collection('progress')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                var progressDocs = snapshot.data!.docs;
                if (progressDocs.isEmpty) {
                  return Center(child: Text("No progress yet."));
                }

                List<DataRow> rows = progressDocs.map((doc) {
                  var pData = doc.data() as Map<String, dynamic>;
                  String progressText = pData['text'] ?? "";
                  bool afterDone = pData['afterTaskDone'] == true;
                  if (afterDone) {
                    progressText += " (after completion)";
                  }
                  Timestamp ts = pData['timestamp'];
                  String date = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
                  String userId = pData['userId'] ?? "Unknown";
                  String? picUrl = pData['pictureUrl'];

                  return DataRow(cells: [
                    DataCell(Text(date)),
                    DataCell(
                      Container(
                        width: 250,
                        child: Text(
                          progressText,
                          softWrap: true,
                          maxLines: null,
                        ),
                      ),
                    ),
                    DataCell(
                      FutureBuilder<String>(
                        future: _getUserName(userId),
                        builder: (context, snapu) {
                          if (snapu.connectionState == ConnectionState.waiting) {
                            return Text("Loading...");
                          } else if (snapu.hasError) {
                            return Text("Error");
                          } else {
                            return Text(snapu.data ?? "Unknown");
                          }
                        },
                      ),
                    ),
                    DataCell(
                      (picUrl != null && picUrl.isNotEmpty)
                          ? InkWell(
                        onTap: () {
                          if (kIsWeb) {
                            html.window.open(picUrl, "_blank");
                          } else {
                            // On mobile, handle accordingly
                          }
                        },
                        child: Text(
                          "View",
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                          : Text("-"),
                    ),
                  ]);
                }).toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 20,
                    dataRowMinHeight: 60,
                    dataRowMaxHeight: 200,
                    columns: [
                      DataColumn(label: Text("Date")),
                      DataColumn(label: Text("Progress")),
                      DataColumn(label: Text("Written by")),
                      DataColumn(label: Text("Image")),
                    ],
                    rows: rows,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
