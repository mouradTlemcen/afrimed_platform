// File: document_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentDetailsPage extends StatefulWidget {
  final String documentId;

  DocumentDetailsPage({required this.documentId});

  @override
  _DocumentDetailsPageState createState() => _DocumentDetailsPageState();
}

class _DocumentDetailsPageState extends State<DocumentDetailsPage> {
  Map<String, dynamic>? documentData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDocument();
  }

  Future<void> _fetchDocument() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('documents')
        .doc(widget.documentId)
        .get();
    if (doc.exists) {
      setState(() {
        documentData = doc.data() as Map<String, dynamic>;
        isLoading = false;
      });
    }
  }

  Future<void> _downloadFile(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open the file.")));
    }
  }

  /// Allows editing the comment for the current regular version.
  Future<void> _editCurrentVersionComment() async {
    TextEditingController commentController = TextEditingController(
        text: documentData?['currentVersionComment'] ?? "");
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Current Version Comment"),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(labelText: "Comment"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
              onPressed: () async {
                String newComment = commentController.text.trim();
                await FirebaseFirestore.instance
                    .collection('documents')
                    .doc(widget.documentId)
                    .update({'currentVersionComment': newComment});
                Navigator.pop(ctx);
                _fetchDocument();
              },
              child: Text("Save")),
        ],
      ),
    );
  }

  /// Allows editing the comment for a history version.
  Future<void> _editHistoryVersionComment(
      int index, Map<String, dynamic> entry) async {
    TextEditingController commentController = TextEditingController(
        text: entry['versionComment'] ?? "");
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit History Version Comment"),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(labelText: "Comment"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
              onPressed: () async {
                String newComment = commentController.text.trim();
                List<dynamic> versionHistory =
                    documentData?['versionHistory'] ?? [];
                if (index >= 0 && index < versionHistory.length) {
                  versionHistory[index]['versionComment'] = newComment;
                  await FirebaseFirestore.instance
                      .collection('documents')
                      .doc(widget.documentId)
                      .update({'versionHistory': versionHistory});
                }
                Navigator.pop(ctx);
                _fetchDocument();
              },
              child: Text("Save")),
        ],
      ),
    );
  }

  /// Allows editing the comment for the current signed version.
  Future<void> _editCurrentSignedVersionComment() async {
    TextEditingController commentController = TextEditingController(
        text: documentData?['currentSignedVersionComment'] ?? "");
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Signed Version Comment"),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(labelText: "Comment"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
              onPressed: () async {
                String newComment = commentController.text.trim();
                await FirebaseFirestore.instance
                    .collection('documents')
                    .doc(widget.documentId)
                    .update({'currentSignedVersionComment': newComment});
                Navigator.pop(ctx);
                _fetchDocument();
              },
              child: Text("Save")),
        ],
      ),
    );
  }

  /// Marks the current version as sent to client.
  Future<void> _markAsSentToClient() async {
    String sender =
        FirebaseAuth.instance.currentUser?.displayName ?? "No username";
    Timestamp now = Timestamp.now();

    // Insert a record in the sentToClient array.
    List<dynamic> sentList = documentData?['sentToClient'] is List
        ? documentData!['sentToClient'] as List<dynamic>
        : <dynamic>[];
    sentList.add({
      'fileName': documentData?['fileName'] ?? "Unknown File",
      'fileUrl': documentData?['fileUrl'] ?? "",
      'sentBy': sender,
      'sentAt': now,
      'clientFeedback': null,
    });

    // Set wasSentToClient flag for the current version.
    await FirebaseFirestore.instance
        .collection('documents')
        .doc(widget.documentId)
        .update({
      'sentToClient': sentList,
      'wasSentToClient': true,
      'wasSentToClientAt': now
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Version marked as sent to client.")));
    _fetchDocument();
  }

  /// Marks the current version as signed by the creator.
  Future<void> _markAsSignedByCreator() async {
    String signer =
        FirebaseAuth.instance.currentUser?.displayName ?? "No username";
    Timestamp now = Timestamp.now();
    await FirebaseFirestore.instance
        .collection('documents')
        .doc(widget.documentId)
        .update({
      'signedByCreator': true,
      'signedByCreatorAt': now
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Version marked as signed by creator.")));
    _fetchDocument();
  }

  /// Marks the current version as signed by the receiver.
  Future<void> _markAsSignedByReceiver() async {
    String signer =
        FirebaseAuth.instance.currentUser?.displayName ?? "No username";
    Timestamp now = Timestamp.now();
    await FirebaseFirestore.instance
        .collection('documents')
        .doc(widget.documentId)
        .update({
      'signedByReceiver': true,
      'signedByReceiverAt': now
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Version marked as signed by receiver.")));
    _fetchDocument();
  }

  /// Adds a new regular version to the document.
  /// Before adding, copies the current version (including signature and sent status)
  /// into the versionHistory and then resets those flags on the new (current) version.
  Future<void> _addNewVersion() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'doc', 'docx'],
      type: FileType.custom,
    );
    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      int currentVersion = documentData?['version'] ?? 0;
      int newVersion = currentVersion + 1;
      String projectNumber = documentData?['projectNumber'] ?? "Unknown";
      String phase = documentData?['phase'] ?? "Unknown";
      String site = documentData?['site'] ?? "Global";
      String docTitle = documentData?['docTitle'] ?? "Document";
      String baseFilename =
          "${projectNumber}_${phase}_${site}_${docTitle}_v$newVersion";
      String filename = baseFilename;

      // Prepare history entry from current version including signature and sent flags.
      List<dynamic> versionHistory = documentData?['versionHistory'] ?? [];
      if (currentVersion > 0 && documentData?['fileName'] != null) {
        Map<String, dynamic> oldEntry = {
          'version': currentVersion,
          'fileName': documentData?['fileName'],
          'fileUrl': documentData?['fileUrl'],
          'uploadedBy': documentData?['uploadedBy'],
          'uploadedAt': documentData?['uploadedAt'],
          'versionComment': documentData?['currentVersionComment'] ?? "",
          'signedByCreator': documentData?['signedByCreator'] ?? false,
          'signedByCreatorAt': documentData?['signedByCreatorAt'],
          'signedByReceiver': documentData?['signedByReceiver'] ?? false,
          'signedByReceiverAt': documentData?['signedByReceiverAt'],
          'wasSentToClient': documentData?['wasSentToClient'] ?? false,
          'wasSentToClientAt': documentData?['wasSentToClientAt'],
        };
        versionHistory.add(oldEntry);
      }

      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("documents")
          .child(filename);
      TaskSnapshot snapshot;
      if (file.bytes != null) {
        snapshot = await storageRef.putData(file.bytes!);
      } else if (file.path != null) {
        snapshot = await storageRef.putFile(File(file.path!));
      } else {
        return;
      }
      String? downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl != null) {
        // Create the new version with cleared signature and sent flags.
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(widget.documentId)
            .update({
          'version': newVersion,
          'fileUrl': downloadUrl,
          'fileName': filename,
          'uploadedBy': FirebaseAuth.instance.currentUser?.displayName ?? "No username",
          'uploadedAt': Timestamp.now(),
          'versionHistory': versionHistory,
          'currentVersionComment': "",
          'signedByCreator': false,
          'signedByCreatorAt': null,
          'signedByReceiver': false,
          'signedByReceiverAt': null,
          'wasSentToClient': false,
          'wasSentToClientAt': null,
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("New version added.")));
        _fetchDocument();
      }
    }
  }

  /// Uploads a new signed version for the document.
  Future<void> _uploadSignedVersion() async {
    if (!(documentData?['requireSignature'] ?? false)) return;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'doc', 'docx'],
      type: FileType.custom,
    );
    if (result != null && result.files.isNotEmpty) {
      PlatformFile file = result.files.first;
      int currentSignedVersion = documentData?['currentSignedVersion'] ?? 0;
      int newSignedVersion = currentSignedVersion + 1;
      String originalFileName = documentData?['fileName'] ?? "unknown";
      String signedFileName = "${originalFileName}_signed_v$newSignedVersion";
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("documents")
          .child(signedFileName);
      TaskSnapshot snapshot;
      if (file.bytes != null) {
        snapshot = await storageRef.putData(file.bytes!);
      } else if (file.path != null) {
        snapshot = await storageRef.putFile(File(file.path!));
      } else {
        return;
      }
      String? downloadUrl = await snapshot.ref.getDownloadURL();
      if (downloadUrl != null) {
        List<dynamic> signedVersionHistory =
            documentData?['signedVersionHistory'] ?? [];
        if (documentData?['currentSignedVersion'] != null) {
          Map<String, dynamic> currentSignedData = {
            'signedVersion': documentData?['currentSignedVersion'],
            'signedFileName': documentData?['currentSignedFileName'],
            'signedFileUrl': documentData?['currentSignedFileUrl'],
            'uploadedBy': documentData?['currentSignedUploadedBy'],
            'uploadedAt': documentData?['currentSignedUploadedAt'],
            'signedVersionComment': documentData?['currentSignedVersionComment'] ?? ""
          };
          signedVersionHistory.add(currentSignedData);
        }
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(widget.documentId)
            .update({
          'currentSignedVersion': newSignedVersion,
          'currentSignedFileName': signedFileName,
          'currentSignedFileUrl': downloadUrl,
          'currentSignedUploadedBy': FirebaseAuth.instance.currentUser?.displayName ?? "No username",
          'currentSignedUploadedAt': Timestamp.now(),
          'currentSignedVersionComment': "",
          'signedVersionHistory': signedVersionHistory
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Signed version uploaded successfully.")));
        _fetchDocument();
      }
    }
  }

  /// Allows adding or editing client feedback for a sent document.
  Future<void> _addClientFeedback(Map<String, dynamic> sentEntry, int index) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      type: FileType.custom,
    );
    String? feedbackFileUrl;
    if (result != null && result.files.isNotEmpty) {
      PlatformFile feedbackFile = result.files.first;
      String feedbackFilename =
          "feedback_${DateTime.now().millisecondsSinceEpoch}_${feedbackFile.name}";
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("documentFeedback")
          .child(feedbackFilename);
      TaskSnapshot snapshot;
      if (feedbackFile.bytes != null) {
        snapshot = await storageRef.putData(feedbackFile.bytes!);
      } else if (feedbackFile.path != null) {
        snapshot = await storageRef.putFile(File(feedbackFile.path!));
      } else {
        return;
      }
      feedbackFileUrl = await snapshot.ref.getDownloadURL();
    }
    TextEditingController commentController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Add Client Feedback"),
        content: TextField(
          controller: commentController,
          decoration: InputDecoration(labelText: "Feedback comment"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
          TextButton(
              onPressed: () async {
                String comment = commentController.text.trim();
                List<dynamic> sentList = documentData?['sentToClient'] is List
                    ? documentData!['sentToClient'] as List<dynamic>
                    : <dynamic>[];
                if (index < sentList.length) {
                  sentList[index]['clientFeedback'] = {
                    'feedbackFileUrl': feedbackFileUrl,
                    'comment': comment,
                    'feedbackAt': Timestamp.now()
                  };
                  await FirebaseFirestore.instance
                      .collection('documents')
                      .doc(widget.documentId)
                      .update({'sentToClient': sentList});
                }
                Navigator.pop(ctx);
                _fetchDocument();
              },
              child: Text("Save")),
        ],
      ),
    );
  }

  /// Deletes a specific version from the version history.
  Future<void> _deleteDocumentVersion(int index) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Version'),
        content: Text('Are you sure you want to delete this document version?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      List<dynamic> versionHistory = documentData?['versionHistory'] ?? [];
      if (index >= 0 && index < versionHistory.length) {
        versionHistory.removeAt(index);
        await FirebaseFirestore.instance
            .collection('documents')
            .doc(widget.documentId)
            .update({'versionHistory': versionHistory});
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Version deleted successfully.')));
        _fetchDocument();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure that 'sentToClient' is treated as a List.
    final List<dynamic> sentList = documentData?['sentToClient'] is List
        ? documentData!['sentToClient'] as List<dynamic>
        : <dynamic>[];

    return Scaffold(
      appBar: AppBar(
        title: Text("Document Details"),
        backgroundColor: Colors.blue[800],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Document basic info and current version with signature labels.
          Row(
            children: [
              Text(
                "Document Title: ${documentData?['docTitle'] ?? "Unknown"}",
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text("Project: ${documentData?['projectNumber'] ?? ""}"),
          Text("Phase: ${documentData?['phase'] ?? ""}"),
          Text("Site: ${documentData?['site'] ?? ""}"),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Current Version: v${documentData?['version'] ?? 0}",
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (documentData?['signedByCreator'] == true)
                Container(
                  margin: EdgeInsets.only(left: 12),
                  padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "Signed by Creator",
                    style:
                    TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              if (documentData?['signedByReceiver'] == true)
                Container(
                  margin: EdgeInsets.only(left: 12),
                  padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "Signed by Receiver",
                    style:
                    TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              if (documentData?['wasSentToClient'] == true)
                Container(
                  margin: EdgeInsets.only(left: 12),
                  padding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.deepPurple,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    "Sent to Client",
                    style:
                    TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
          if (documentData?['uploadedBy'] != null)
            Text(
              "Uploaded by: ${documentData?['uploadedBy']}",
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          Row(
            children: [
              Expanded(
                child: documentData?['fileUrl'] != null
                    ? InkWell(
                  onTap: () =>
                      _downloadFile(documentData!['fileUrl']),
                  child: Text(
                    documentData?['fileName'] ?? "Unknown File",
                    style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                )
                    : Text("No file uploaded"),
              ),
              IconButton(
                  icon: Icon(Icons.comment, color: Colors.blue),
                  tooltip: "Edit comment for current version",
                  onPressed: _editCurrentVersionComment),
            ],
          ),
          if (documentData?['currentVersionComment'] != null &&
              documentData!['currentVersionComment']
                  .toString()
                  .isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                "Comment: ${documentData?['currentVersionComment']}",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          SizedBox(height: 16),
          ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text("Add New Version"),
              onPressed: _addNewVersion,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue)),
          SizedBox(height: 16),
          if (documentData?['requireSignature'] == true)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Signed Version:",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Expanded(
                      child: documentData?['currentSignedFileUrl'] != null
                          ? InkWell(
                        onTap: () => _downloadFile(
                            documentData!['currentSignedFileUrl']),
                        child: Text(
                          documentData?['currentSignedFileName'] ??
                              "Unknown Signed File",
                          style: TextStyle(
                              color: Colors.blue,
                              decoration:
                              TextDecoration.underline),
                        ),
                      )
                          : Text("No signed version uploaded"),
                    ),
                    IconButton(
                        icon: Icon(Icons.comment,
                            color: Colors.redAccent),
                        tooltip: "Edit comment for signed version",
                        onPressed: _editCurrentSignedVersionComment),
                  ],
                ),
                if (documentData?['currentSignedVersionComment'] != null &&
                    documentData!['currentSignedVersionComment']
                        .toString()
                        .isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      "Comment: ${documentData?['currentSignedVersionComment']}",
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                SizedBox(height: 8),
                ElevatedButton.icon(
                    icon: Icon(Icons.edit),
                    label: Text("Upload New Signed Version"),
                    onPressed: _uploadSignedVersion,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent)),
                SizedBox(height: 16),
                Text(
                  "Signed Version History:",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                ...((documentData?['signedVersionHistory']
                as List<dynamic>?) ??
                    [])
                    .asMap()
                    .entries
                    .map((entry) {
                  int idx = entry.key;
                  Map<String, dynamic> history = entry.value;
                  return ListTile(
                    title: InkWell(
                      onTap: () => _downloadFile(history['signedFileUrl']),
                      child: Text(
                        "v${history['signedVersion']}: ${history['signedFileName']}",
                        style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Uploaded by: ${history['uploadedBy'] ?? "No username"} on ${history['uploadedAt'] != null ? DateFormat('yyyy-MM-dd').format((history['uploadedAt'] as Timestamp).toDate()) : ""}",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        IconButton(
                            icon: Icon(Icons.comment,
                                size: 20, color: Colors.redAccent),
                            tooltip:
                            "Edit comment for this history version",
                            onPressed: () =>
                                _editHistoryVersionComment(idx, history))
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          Divider(),
          Text(
            "Version History:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ...((documentData?['versionHistory'] as List<dynamic>?) ?? [])
              .asMap()
              .entries
              .map((entry) {
            int idx = entry.key;
            Map<String, dynamic> history = entry.value;
            // For history entries, get the flags safely:
            bool signedCreator = history['signedByCreator'] == true;
            bool signedReceiver = history['signedByReceiver'] == true;
            bool wasSent = history['wasSentToClient'] == true;

            return ListTile(
              title: InkWell(
                onTap: () => _downloadFile(history['fileUrl']),
                child: Text(
                  "v${history['version']}: ${history['fileName']}",
                  style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Uploaded by: ${history['uploadedBy'] ?? "No username"} on ${history['uploadedAt'] != null ? DateFormat('yyyy-MM-dd').format((history['uploadedAt'] as Timestamp).toDate()) : ""}",
                  ),
                  if ((history['versionComment'] ?? "").isNotEmpty)
                    Text("Comment: ${history['versionComment']}"),
                  Row(
                    children: [
                      if (signedCreator)
                        Container(
                          margin: EdgeInsets.only(top: 4, right: 6),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            "Signed by Creator",
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      if (signedReceiver)
                        Container(
                          margin: EdgeInsets.only(top: 4, right: 6),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            "Signed by Receiver",
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      if (wasSent)
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            "Sent to Client",
                            style: TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  )
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                tooltip: "Delete this version from history",
                onPressed: () => _deleteDocumentVersion(idx),
              ),
            );
          }).toList(),
          Divider(),
          Text(
            "Documents Sent to Client:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          sentList.isEmpty
              ? Text("No documents sent to client yet.")
              : Column(
            children: sentList.asMap().entries.map((entry) {
              int idx = entry.key;
              Map<String, dynamic> sent = entry.value;
              return ListTile(
                title: InkWell(
                  onTap: () {
                    if (sent['fileUrl'] != null) {
                      _downloadFile(sent['fileUrl']);
                    }
                  },
                  child: Text(
                    sent['fileName'] ?? "Unknown File",
                    style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                ),
                subtitle: Text(
                  "Sent by: ${sent['sentBy'] ?? "No username"} on ${sent['sentAt'] != null ? DateFormat('yyyy-MM-dd').format((sent['sentAt'] as Timestamp).toDate()) : ""}",
                  style: TextStyle(fontSize: 14),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.comment, color: Colors.redAccent),
                  tooltip: "Add/Edit Client Feedback",
                  onPressed: () => _addClientFeedback(sent, idx),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          // New buttons for marking signatures.
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.send),
                  label: Text("Mark as Sent to Client"),
                  onPressed: _markAsSentToClient,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.person),
                  label: Text("Signed by Creator"),
                  onPressed: _markAsSignedByCreator,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.person),
                  label: Text("Signed by Receiver"),
                  onPressed: _markAsSignedByReceiver,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
