// File: add_document_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddDocumentPage extends StatefulWidget {
  @override
  _AddDocumentPageState createState() => _AddDocumentPageState();
}

class _AddDocumentPageState extends State<AddDocumentPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic form fields.
  String? selectedProjectId;
  String? selectedProjectNumber;
  // Default Phase to "Global" (manually provided in dropdown).
  String _phase = "Global";
  String _site = "Global"; // Default to "Global"
  bool requireSignature = false;

  // CreatedBy is now selected from a dropdown of partner names.
  String _createdBy = "AFRIMED";
  List<String> partnerNames = ["AFRIMED"]; // Start with AFRIMED as the default

  // Toggle for document type: Standard vs Extra.
  bool isStandard = true;
  String? selectedStandardDocTitle;
  TextEditingController extraDocTitleController = TextEditingController();

  PlatformFile? selectedFile;

  // Data for the project and site dropdowns.
  List<Map<String, dynamic>> projects = [];
  List<Map<String, dynamic>> sites = []; // Fetched sites for the selected project

  // Predefined phases (do not include "Global" here to avoid duplication).
  final List<String> phases = [
    "Tender Preparation and submission",
    "Order preparation",
    "Factory test",
    "Shipment",
    "Site preparation",
    "Installation and training",
    "Commissioning",
    "Warranty period",
    "After warranty period"
  ];

  // Flag to indicate saving progress.
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchPartnerNames(); // Fetch partner names for CreatedBy dropdown
    _updateAllNullCreatedBy(); // One-time update to set null createdBy fields to "AFRIMED"
  }

  // Fetch projects from Firestore (using 'Afrimed_projectId').
  Future<void> _fetchProjects() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('projects').get();
    setState(() {
      projects = snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'projectNumber': data['Afrimed_projectId']?.toString() ?? "Unknown",
        };
      }).toList();
    });
  }

  // Fetch partner names from Firestore (partners collection).
  Future<void> _fetchPartnerNames() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('partners').get();

    // For each partner doc, retrieve the top-level 'name' field, if it exists.
    List<String> fetchedNames = snapshot.docs.map<String>((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Use the top-level 'name' field.
      final partnerName = data['name']?.toString() ?? "Unknown Partner";
      return partnerName;
    }).toList();

    // Remove duplicate names by converting the list to a Set, then back to a List.
    List<String> uniqueNames = Set<String>.from(fetchedNames).toList();

    setState(() {
      // Start with AFRIMED, then add all unique partner names.
      partnerNames = ["AFRIMED", ...uniqueNames];
    });
  }


  // Fetch sites from the selected project's lots subcollection.
  Future<void> _fetchSites(String projectId) async {
    QuerySnapshot lotSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('lots')
        .get();
    List<Map<String, dynamic>> fetchedSites = [];
    // Do not add "Global" here because we add it manually in the dropdown items.
    for (var lot in lotSnapshot.docs) {
      QuerySnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('lots')
          .doc(lot.id)
          .collection('sites')
          .get();
      for (var siteDoc in siteSnapshot.docs) {
        var data = siteDoc.data() as Map<String, dynamic>;
        String siteName = data['siteName']?.toString() ?? "Unnamed Site";
        // Exclude duplicates of "Global" if present in Firestore.
        if (siteName.toLowerCase() != "global") {
          fetchedSites.add({
            'id': siteDoc.id,
            'siteName': siteName,
          });
        }
      }
    }
    setState(() {
      sites = fetchedSites;
    });
  }

  /// Picks a file (PDF, DOC, DOCX) from the user's device.
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf', 'doc', 'docx'],
      type: FileType.custom,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedFile = result.files.first;
      });
    }
  }

  /// Uploads the picked file to Firebase Storage using the given filename.
  Future<String?> _uploadFile(PlatformFile file, String filename) async {
    try {
      Reference storageRef =
      FirebaseStorage.instance.ref().child("documents").child(filename);
      TaskSnapshot snapshot;
      if (file.bytes != null) {
        snapshot = await storageRef.putData(file.bytes!);
      } else if (file.path != null) {
        snapshot = await storageRef.putFile(File(file.path!));
      } else {
        return null;
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading file: $e");
      return null;
    }
  }

  /// Retrieve the user's full name from Firestore (for 'uploadedBy' field).
  Future<String> _getUserFullName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return "No username";
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      var data = userDoc.data() as Map<String, dynamic>;
      String firstName = data['firstName'] ?? "";
      String lastName = data['lastName'] ?? "";
      String fullName = (firstName + " " + lastName).trim();
      return fullName.isNotEmpty ? fullName : "No username";
    }
    return "No username";
  }

  /// Fetch document titles from the obligatory_documents collection (global list)
  /// based on the selected phase (the obligatory documents are global)
  /// and also fetch the already uploaded doc titles from the documents collection.
  Future<Map<String, dynamic>> _fetchDocTitlesForStandard() async {
    if (selectedProjectNumber == null || _phase.isEmpty) {
      return {
        'requiredTitles': <String>{},
        'alreadyUploaded': <String>{},
      };
    }
    QuerySnapshot reqSnapshot = await FirebaseFirestore.instance
        .collection('global_obligatory_documents')
        .where('phase', isEqualTo: _phase)
        .get();
    Set<String> requiredTitles = reqSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['docTitle'] as String? ?? "";
    }).toSet();

    QuerySnapshot upSnapshot = await FirebaseFirestore.instance
        .collection('documents')
        .where('projectNumber', isEqualTo: selectedProjectNumber)
        .where('phase', isEqualTo: _phase)
        .where('site', isEqualTo: _site)
        .where('standardStatus', isEqualTo: "Already Uploaded")
        .get();
    Set<String> alreadyUploaded = upSnapshot.docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      return data['docTitle'] as String? ?? "";
    }).toSet();

    return {
      'requiredTitles': requiredTitles,
      'alreadyUploaded': alreadyUploaded,
    };
  }

  /// Save the document to Firestore.
  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate() || selectedFile == null) return;
    setState(() {
      _isSaving = true;
    });
    _formKey.currentState!.save();

    String finalDocTitle;
    if (isStandard) {
      if (selectedStandardDocTitle == null || selectedStandardDocTitle!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select a standard document title.")),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }
      finalDocTitle = selectedStandardDocTitle!;
    } else {
      if (extraDocTitleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter a document title.")),
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }
      finalDocTitle = extraDocTitleController.text.trim();
    }

    String fileNameWithoutExt = selectedFile!.name.split('.').first.trim();
    if (fileNameWithoutExt != finalDocTitle) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("The file name must exactly match the document title.")),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    String versionStr = "v1";
    String filename =
        "${selectedProjectNumber}_${_phase}_${_site}_${finalDocTitle}_$versionStr";

    String? fileUrl = await _uploadFile(selectedFile!, filename);
    if (fileUrl == null) {
      setState(() {
        _isSaving = false;
      });
      return;
    }

    String uploader = await _getUserFullName();

    DocumentReference newDocRef =
    FirebaseFirestore.instance.collection('documents').doc();
    await newDocRef.set({
      'projectId': selectedProjectId,
      'projectNumber': selectedProjectNumber,
      'phase': _phase,
      'site': _site,
      'docTitle': finalDocTitle,
      'version': 1,
      'fileUrl': fileUrl,
      'fileName': filename,
      'requireSignature': requireSignature,
      'uploadedBy': uploader,
      'uploadedAt': Timestamp.now(),
      'standardStatus': "Already Uploaded",
      'versionHistory': [],
      'scope': (_site.toLowerCase() == "global") ? "global" : "site",
      'createdBy': _createdBy
    });

    // Call the helper to update documents with null createdBy.
    await _updateAllNullCreatedBy();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Document added successfully!")),
    );
    setState(() {
      _isSaving = false;
    });
    Navigator.pop(context);
  }

  /// One-time helper to update all documents in the 'documents' collection that have a null 'createdBy' field.
  /// This function sets the 'createdBy' field to "AFRIMED" for any such document.
  Future<void> _updateAllNullCreatedBy() async {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('documents')
        .where('createdBy', isNull: true)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.update({'createdBy': 'AFRIMED'});
      print("Updated doc ${doc.id}: set createdBy to AFRIMED");
    }
    print("All null createdBy fields have been updated.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add Document"),
        backgroundColor: Colors.blue[800],
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Project Dropdown (with Global option)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Project",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedProjectNumber,
                    items: [
                      DropdownMenuItem<String>(
                        value: "Global",
                        child: Text("Global"),
                      ),
                      ...projects.map<DropdownMenuItem<String>>((proj) {
                        return DropdownMenuItem<String>(
                          value: proj['projectNumber'].toString(),
                          child: Text(proj['projectNumber'].toString()),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedProjectNumber = value;
                        if (value == "Global") {
                          selectedProjectId = null;
                          sites = [];
                        } else {
                          var proj = projects.firstWhere(
                                  (p) => p['projectNumber'].toString() == value);
                          selectedProjectId = proj['id'];
                          _fetchSites(selectedProjectId!);
                        }
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return "Please select a project";
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  // Phase Dropdown (with Global option)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Phase",
                      border: OutlineInputBorder(),
                    ),
                    value: _phase,
                    items: [
                      DropdownMenuItem<String>(
                        value: "Global",
                        child: Text("Global"),
                      ),
                      ...phases.map<DropdownMenuItem<String>>((ph) {
                        return DropdownMenuItem<String>(
                          value: ph,
                          child: Text(ph),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _phase = value!;
                        selectedStandardDocTitle = null;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // Site Dropdown (Global plus project-specific sites)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Site",
                      border: OutlineInputBorder(),
                    ),
                    value: _site,
                    items: [
                      DropdownMenuItem<String>(
                        value: "Global",
                        child: Text("Global"),
                      ),
                      ...sites.map<DropdownMenuItem<String>>((siteData) {
                        return DropdownMenuItem<String>(
                          value: siteData['siteName'].toString(),
                          child: Text(siteData['siteName'].toString()),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _site = value!;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // Document Type: Standard vs Extra
                  Row(
                    children: [
                      Text("Document Type: "),
                      SizedBox(width: 8),
                      Row(
                        children: [
                          Radio<bool>(
                            value: true,
                            groupValue: isStandard,
                            onChanged: (val) {
                              setState(() {
                                isStandard = val!;
                              });
                            },
                          ),
                          Text("Standard"),
                        ],
                      ),
                      SizedBox(width: 16),
                      Row(
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: isStandard,
                            onChanged: (val) {
                              setState(() {
                                isStandard = val!;
                              });
                            },
                          ),
                          Text("Extra"),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  // CreatedBy Dropdown - fetch from partner names, default = "AFRIMED".
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Created By",
                      border: OutlineInputBorder(),
                    ),
                    value: _createdBy,
                    items: partnerNames.map<DropdownMenuItem<String>>((name) {
                      return DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _createdBy = value!;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please select the creator/owner.";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  // If Standard, show the dropdown for missing obligatory document titles.
                  // Otherwise, show a text field.
                  isStandard
                      ? FutureBuilder<Map<String, dynamic>>(
                    future: _fetchDocTitlesForStandard(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final requiredTitles =
                      snapshot.data!['requiredTitles'] as Set<String>;
                      final alreadyUploaded =
                      snapshot.data!['alreadyUploaded'] as Set<String>;
                      final missingTitles = requiredTitles.difference(alreadyUploaded);

                      if (missingTitles.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "All obligatory standard documents have been uploaded.",
                            style: TextStyle(color: Colors.green),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: "Document Title",
                          border: OutlineInputBorder(),
                        ),
                        value: selectedStandardDocTitle,
                        items: missingTitles.map((title) {
                          return DropdownMenuItem<String>(
                            value: title,
                            child: Text(title),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStandardDocTitle = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Please select a document title";
                          }
                          return null;
                        },
                      );
                    },
                  )
                      : TextFormField(
                    controller: extraDocTitleController,
                    decoration: InputDecoration(
                      labelText: "Document Title",
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a document title";
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 8),
                  // Require Signature checkbox.
                  CheckboxListTile(
                    title: Text("Require Signed Version"),
                    value: requireSignature,
                    onChanged: (val) {
                      setState(() {
                        requireSignature = val ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  // File Picker button.
                  ElevatedButton.icon(
                    icon: Icon(Icons.upload_file),
                    label: Text(
                      selectedFile != null
                          ? "File Selected: ${selectedFile!.name}"
                          : "Select File",
                    ),
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  ),
                  SizedBox(height: 16),
                  // Save Document button with progress indicator handling.
                  ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("Add Document"),
                    onPressed: _isSaving ? null : _saveDocument,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
