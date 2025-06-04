import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Temporarily removed: import 'equipment_details_page.dart';

class PSADetailsPage extends StatefulWidget {
  final String psaId;
  final Map<String, dynamic> psaData;

  PSADetailsPage({required this.psaId, required this.psaData});

  @override
  _PSADetailsPageState createState() => _PSADetailsPageState();
}

class _PSADetailsPageState extends State<PSADetailsPage> {
  String siteName = "Loading..."; // Default site name

  @override
  void initState() {
    super.initState();
    _fetchSiteName();
  }

  /// Fetch site name using `siteId` from Firestore
  Future<void> _fetchSiteName() async {
    if (widget.psaData['siteId'] != null) {
      DocumentSnapshot siteSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.psaData['projectId']) // Project ID
          .collection('lots')
          .doc(widget.psaData['lotId']) // Lot ID
          .collection('sites')
          .doc(widget.psaData['siteId']) // Site ID
          .get();

      if (siteSnapshot.exists) {
        setState(() {
          siteName = (siteSnapshot.data() as Map<String, dynamic>)['siteName'] ?? "Unknown";
        });
      } else {
        setState(() {
          siteName = "Site not found";
        });
      }
    } else {
      setState(() {
        siteName = "No site linked";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PSA Details"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              "PSA Reference: ${widget.psaData['reference']}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text("Project ID: ${widget.psaData['projectId']}"),
            Text("Site: $siteName"),
            Text("Created At: ${widget.psaData['createdAt'].toDate()}"),
            const SizedBox(height: 16),
            // Temporarily removed: Linked Equipment section.
            const Text(
              "Equipment linking is temporarily removed.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
