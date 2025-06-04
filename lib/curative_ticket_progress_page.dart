import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Additional imports for PDF generation
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;

import 'progress_images_page.dart';
// If you have a separate SparePartReplacementPage, import it here:
// import 'spare_part_replacement_page.dart';

/// A simple model that wraps an image file (XFile) and a TextEditingController for its comment.
class DiagnosticPicture {
  final XFile file;
  final TextEditingController commentController;
  DiagnosticPicture({required this.file})
      : commentController = TextEditingController();
}

class CurativeTicketProgressPage extends StatefulWidget {
  final String ticketId;

  const CurativeTicketProgressPage({Key? key, required this.ticketId})
      : super(key: key);

  @override
  _CurativeTicketProgressPageState createState() =>
      _CurativeTicketProgressPageState();
}

class _CurativeTicketProgressPageState
    extends State<CurativeTicketProgressPage> {
  final TextEditingController progressController = TextEditingController();

  // For the spare part dropdown
  String? _selectedSparePart;
  List<String> _sparePartOptions = [];
  bool _sparePartLoading = false;
  String? _sparePartError;

  // Equipment spare part details from the equipment document.
  String? _currentSparePart;

  String? currentStatus;
  String? _equipmentId;     // from ticket doc
  String? _equipmentName;   // from ticket doc

  // Holds our selected images and their comment controllers.
  List<DiagnosticPicture> _diagnosticPictures = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  /// Loads the ticket doc to get status, equipmentId, and equipmentName.
  /// Then loads equipment data (e.g. current spare part) and fetches spare parts.
  void _loadTicketDetails() async {
    try {
      print("=== _loadTicketDetails() called for ticketId: ${widget.ticketId}");
      DocumentSnapshot ticketDoc = await FirebaseFirestore.instance
          .collection('curative_maintenance_tickets')
          .doc(widget.ticketId)
          .get();

      if (!ticketDoc.exists) {
        setState(() {
          currentStatus = "Unknown";
          _sparePartError = "Ticket not found in Firestore.";
        });
        print("=== Ticket not found in Firestore for ID: ${widget.ticketId}");
        return;
      }

      var data = ticketDoc.data() as Map<String, dynamic>;
      print("=== Ticket doc data: $data");

      setState(() {
        currentStatus = data['status'] ?? "Unknown";
        _equipmentId = data['equipmentId'];       // The real doc ID from 'equipment'
        _equipmentName = data['equipmentName'];   // For display
      });

      print("=== Equipment ID from ticket: $_equipmentId");
      print("=== Equipment Name from ticket: $_equipmentName");
      print("=== Current status: $currentStatus");

      // Load equipment data (e.g., current spare part)
      await _loadEquipmentData();
      // Now fetch the spare parts from equipment/{_equipmentId}/spareParts
      await _fetchSpareParts();
    } catch (e) {
      setState(() {
        _sparePartError = "Error loading ticket details: $e";
      });
      print("=== Exception in _loadTicketDetails: $e");
    }
  }

  /// Loads equipment data from the 'equipment' document (like current spare part).
  Future<void> _loadEquipmentData() async {
    if (_equipmentId == null || _equipmentId!.isEmpty) return;
    try {
      DocumentSnapshot eqDoc = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(_equipmentId)
          .get();
      if (eqDoc.exists) {
        var eqData = eqDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentSparePart = eqData['currentSparePart'] ?? "None";
        });
        print("=== Current Spare Part in equipment doc: $_currentSparePart");
      }
    } catch (e) {
      print("=== Error loading equipment data: $e");
    }
  }

  /// Fetch spare parts from subcollection: equipment/{_equipmentId}/spareParts.
  /// Builds a display name from "type", "brand", and "model".
  Future<void> _fetchSpareParts() async {
    print("=== _fetchSpareParts() called. _equipmentId=$_equipmentId");
    if (_equipmentId == null || _equipmentId!.isEmpty) {
      setState(() {
        _sparePartOptions = [];
        _sparePartError = "No equipment ID found in ticket doc.";
      });
      return;
    }
    setState(() {
      _sparePartLoading = true;
      _sparePartError = null;
      _sparePartOptions.clear();
      _selectedSparePart = null;
    });

    try {
      // Query the subcollection
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(_equipmentId)
          .collection('spareParts')
          .get();

      // Always start with "General progress" as the default
      List<String> parts = ["General progress"];

      if (snapshot.docs.isEmpty) {
        // If no spare-part docs at all, you can still keep "General progress"
        // or add a message for the user:
        // parts.add("Please add the spare part to the equipment");
      } else {
        // Otherwise, add each real spare part
        for (var doc in snapshot.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String type = data['type']?.toString() ?? "";
          String brand = data['brand']?.toString() ?? "";
          String model = data['model']?.toString() ?? "";

          String displayName = type.isNotEmpty ? type : "Unnamed SparePart";
          if (brand.isNotEmpty || model.isNotEmpty) {
            displayName += " ($brand-$model)";
          }
          parts.add(displayName);
        }
      }

      setState(() {
        _sparePartOptions = parts;
        // Make "General progress" the default selection
        _selectedSparePart = "General progress";
        _sparePartLoading = false;
      });

    } catch (e) {
      print("=== Exception in _fetchSpareParts: $e");
      setState(() {
        _sparePartError = "Error fetching spare parts: $e";
        _sparePartLoading = false;
      });
    }
  }


  /// Picks an image using ImagePicker and adds it as a DiagnosticPicture.
  Future<void> _pickDiagnosticPicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
    await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _diagnosticPictures.add(DiagnosticPicture(file: pickedFile));
      });
    }
  }

  /// Builds a preview widget for a single DiagnosticPicture.
  Widget _buildDiagnosticPictureItem(DiagnosticPicture diagPic, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              color: Colors.grey.shade200,
              child: kIsWeb
                  ? FutureBuilder<Uint8List>(
                future: diagPic.file.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Icon(Icons.error, color: Colors.red);
                  } else if (!snapshot.hasData || snapshot.data == null) {
                    return const Icon(Icons.broken_image, color: Colors.grey);
                  } else {
                    final bytes = snapshot.data!;
                    return Image.memory(bytes, fit: BoxFit.cover);
                  }
                },
              )
                  : Image.file(File(diagPic.file.path), fit: BoxFit.cover),
            ),
            const SizedBox(width: 8),
            Container(
              width: 200,
              child: TextFormField(
                controller: diagPic.commentController,
                decoration: const InputDecoration(
                  labelText: "Picture Comment",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  _diagnosticPictures.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Uploads all diagnostic pictures to Firebase Storage and returns a list of maps with imageUrl and comment.
  Future<List<Map<String, String>>> _uploadDiagnosticPictures() async {
    List<Map<String, String>> diagnosticPicturesData = [];
    for (DiagnosticPicture diagPic in _diagnosticPictures) {
      String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${diagPic.file.name}";
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("progressImages")
          .child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        Uint8List fileBytes = await diagPic.file.readAsBytes();
        snapshot = await storageRef.putData(fileBytes);
      } else {
        File localFile = File(diagPic.file.path);
        snapshot = await storageRef.putFile(localFile);
      }

      String downloadUrl = await snapshot.ref.getDownloadURL();
      diagnosticPicturesData.add({
        "imageUrl": downloadUrl,
        "comment": diagPic.commentController.text.trim(),
      });
    }
    return diagnosticPicturesData;
  }

  /// Submits the progress update to Firestore.
  Future<void> _submitProgress() async {
    String progressText = progressController.text.trim();

    bool validSparePart = true;
    if (_sparePartOptions.length == 1 &&
        (_sparePartOptions.first.startsWith("Please add") ||
            _sparePartOptions.first.startsWith("No equipment"))) {
      validSparePart = false;
    }

    if (progressText.isEmpty &&
        _diagnosticPictures.isEmpty &&
        (!validSparePart || _selectedSparePart == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Please enter progress details, select a spare part, or add at least one image."),
        ),
      );
      return;
    }
    Timestamp now = Timestamp.now();

    List<Map<String, String>> diagnosticPicturesData =
    _diagnosticPictures.isNotEmpty ? await _uploadDiagnosticPictures() : [];

    Map<String, dynamic> progressData = {
      'text': progressText,
      'timestamp': now,
      'pictures': diagnosticPicturesData,
    };

    if (validSparePart && _selectedSparePart != null && _selectedSparePart!.isNotEmpty) {
      progressData['sparePartSelected'] = _selectedSparePart;
    }

    await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .doc(widget.ticketId)
        .collection('progress')
        .add(progressData);

    DocumentReference ticketRef = FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .doc(widget.ticketId);
    DocumentSnapshot ticketDoc = await ticketRef.get();
    var data = ticketDoc.data() as Map<String, dynamic>;
    if (data['status'] == 'Open') {
      await ticketRef.update({
        'status': 'In Progress',
        'lastProgressAt': now,
      });
      setState(() {
        currentStatus = 'In Progress';
      });
    } else {
      await ticketRef.update({'lastProgressAt': now});
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Progress updated")),
    );
    progressController.clear();
    setState(() {
      _diagnosticPictures.clear();
    });
    _loadTicketDetails();
  }

  /// Marks the ticket as completed.
  void _markTicketCompleted() async {
    await FirebaseFirestore.instance
        .collection('curative_maintenance_tickets')
        .doc(widget.ticketId)
        .update({'status': 'Completed'});
    setState(() {
      currentStatus = 'Completed';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ticket marked as Completed")),
    );
  }

  /// Builds a horizontally scrolling preview of the selected diagnostic pictures.
  Widget _buildDiagnosticPicturesPreview() {
    if (_diagnosticPictures.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Selected Images & Comments:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _diagnosticPictures.length,
            itemBuilder: (context, index) {
              return _buildDiagnosticPictureItem(
                  _diagnosticPictures[index], index);
            },
          ),
        ),
      ],
    );
  }

  /// Opens a page to display attached images in detail.
  void _openProgressImagesPage(List<dynamic> pictures) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgressImagesPage(pictures: pictures),
      ),
    );
  }

  /// Downloads all progress updates as a PDF.
  Future<void> _downloadAllProgressAsPdf() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('curative_maintenance_tickets')
          .doc(widget.ticketId)
          .collection('progress')
          .orderBy('timestamp', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No progress to download.")),
        );
        return;
      }

      final pdfDoc = pw.Document();
      List<pw.Widget> progressWidgets = [];

      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        Timestamp ts = data['timestamp'];
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
        String text = data['text'] ?? "";
        String sparePart = data['sparePartSelected'] ?? "";
        List pictures = data['pictures'] ?? [];

        List<pw.Widget> entryWidgets = [
          pw.Text("Date: $dateStr",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Progress: $text"),
        ];

        if (sparePart.isNotEmpty) {
          entryWidgets.add(
            pw.Text("Spare Part: $sparePart",
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
          );
        }

        for (var pic in pictures) {
          String imageUrl = pic['imageUrl'] ?? "";
          String comment = pic['comment'] ?? "";
          if (imageUrl.isNotEmpty) {
            try {
              final response = await http.get(Uri.parse(imageUrl));
              if (response.statusCode == 200) {
                Uint8List imageBytes = response.bodyBytes;
                entryWidgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 8),
                    child: pw.Image(pw.MemoryImage(imageBytes), width: 200),
                  ),
                );
                if (comment.isNotEmpty) {
                  entryWidgets.add(
                    pw.Text("Comment: $comment",
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic)),
                  );
                }
              }
            } catch (e) {
              entryWidgets.add(
                pw.Text("Error loading image: $imageUrl"),
              );
            }
          }
        }

        entryWidgets.add(pw.Divider());
        progressWidgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: entryWidgets,
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
          ..download = "ticket_${widget.ticketId}_progress.pdf";
        html.document.body!.children.add(anchor);
        anchor.click();
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("PDF download is implemented for web. On mobile, implement local saving.")),
        );
      }
    } catch (e) {
      print("Error downloading progress as PDF: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error downloading progress as PDF: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String eqDisplay = "No equipment set.";
    if (_equipmentName != null && _equipmentName!.isNotEmpty) {
      eqDisplay = _equipmentName!;
    } else if (_equipmentId != null && _equipmentId!.isNotEmpty) {
      eqDisplay = "Equipment ID: $_equipmentId";
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Curative Ticket Progress"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Add Progress Update",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Concerned Equipment: $eqDisplay",
              style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Text(
              "Current Spare Part: ${_currentSparePart ?? "Not set"}",
              style: const TextStyle(fontSize: 14, color: Colors.deepOrange),
            ),
            const SizedBox(height: 8),
            // Button to navigate to spare part replacement page (if you have it):
            // ElevatedButton(
            //   onPressed: () {
            //     if (_equipmentId != null && _equipmentId!.isNotEmpty) {
            //       Navigator.push(
            //         context,
            //         MaterialPageRoute(
            //           builder: (context) => SparePartReplacementPage(equipmentId: _equipmentId!),
            //         ),
            //       ).then((value) {
            //         // Reload equipment data after replacement
            //         _loadEquipmentData();
            //       });
            //     } else {
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(content: Text("No equipment linked to this ticket.")),
            //       );
            //     }
            //   },
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.deepOrange,
            //   ),
            //   child: const Text("Replace Spare Part"),
            // ),
            // (Uncomment the above if you want a "Replace Spare Part" button to open a separate page.)

            const SizedBox(height: 16),
            // Progress text
            TextField(
              controller: progressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter progress details",
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            // Spare part dropdown section
            if (_sparePartLoading)
              const Center(child: CircularProgressIndicator())
            else if (_sparePartError != null)
              Text(
                _sparePartError!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else if (_sparePartOptions.isEmpty)
                const Text(
                  "No spare parts found or no equipment ID is set.",
                  style: TextStyle(color: Colors.grey),
                )
              else
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Select Spare Part",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  value: _selectedSparePart,
                  items: _sparePartOptions.map((sp) {
                    return DropdownMenuItem<String>(
                      value: sp,
                      child: Text(sp),
                    );
                  }).toList(),
                  onChanged: (_sparePartOptions.length == 1 &&
                      (_sparePartOptions.first.startsWith("Please add") ||
                          _sparePartOptions.first.startsWith("No equipment")))
                      ? null
                      : (value) {
                    setState(() {
                      _selectedSparePart = value;
                    });
                  },
                ),
            const SizedBox(height: 16),
            // Add Image
            ElevatedButton.icon(
              onPressed: _pickDiagnosticPicture,
              icon: const Icon(Icons.image),
              label: const Text("Add Image"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
            ),
            _buildDiagnosticPicturesPreview(),
            const SizedBox(height: 16),
            // Submit progress
            ElevatedButton(
              onPressed: _submitProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text("Submit Progress"),
            ),
            const SizedBox(height: 16),
            // Mark as completed
            ElevatedButton(
              onPressed: _markTicketCompleted,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text("Mark Ticket as Completed"),
            ),
            const SizedBox(height: 16),
            // Download PDF
            ElevatedButton.icon(
              onPressed: _downloadAllProgressAsPdf,
              icon: const Icon(Icons.download),
              label: const Text("Download All Progress (PDF)"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 24),
            // Show progress updates
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('curative_maintenance_tickets')
                    .doc(widget.ticketId)
                    .collection('progress')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No progress updates yet."));
                  }
                  final progressDocs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: progressDocs.length,
                    itemBuilder: (context, index) {
                      var progressData =
                      progressDocs[index].data() as Map<String, dynamic>;
                      Timestamp ts = progressData['timestamp'];
                      String dateStr = DateFormat('yyyy-MM-dd – kk:mm')
                          .format(ts.toDate());
                      String text = progressData['text'] ?? "";
                      String sparePart = progressData['sparePartSelected'] ?? "";
                      List<dynamic> pictures = progressData['pictures'] ?? [];

                      Widget? leadingWidget;
                      if (pictures.isNotEmpty) {
                        final Map<String, dynamic> firstPic = pictures[0];
                        String thumbUrl = firstPic['imageUrl'] ?? "";
                        if (thumbUrl.isNotEmpty) {
                          leadingWidget = ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              thumbUrl,
                              height: 50,
                              width: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error, size: 50);
                              },
                            ),
                          );
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        child: ListTile(
                          leading: leadingWidget,
                          title: Text(
                            text,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Updated on: $dateStr"),
                              if (sparePart.isNotEmpty)
                                Text(
                                  "Spare Part: $sparePart",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              if (pictures.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => _openProgressImagesPage(pictures),
                                  icon: const Icon(Icons.image, size: 16),
                                  label: const Text(
                                    "Click for more details",
                                    style: TextStyle(fontSize: 12),
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
            ),
          ],
        ),
      ),
    );
  }
}
