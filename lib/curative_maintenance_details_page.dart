// File: curative_maintenance_details_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class CurativeMaintenanceDetailsPage extends StatelessWidget {
  final String ticketId;

  // The report file URL (you can also fetch this from Firestore if stored in the document)
  final String reportFileUrl =
      "https://firebasestorage.googleapis.com/v0/b/benosafrimed..."
      "YOUR_FILE_URL_HERE.docx?alt=media&token=3126723f-df05-460e-85d9-60a23df9c7a9";

  CurativeMaintenanceDetailsPage({required this.ticketId});

  /// Launch the URL using url_launcher package.
  Future<void> _downloadReport() async {
    if (await canLaunch(reportFileUrl)) {
      await launch(reportFileUrl);
    } else {
      throw 'Could not launch $reportFileUrl';
    }
  }

  /// Helper method to safely parse and format a Timestamp value.
  String _formatTimestamp(dynamic ts) {
    if (ts is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    } else if (ts != null) {
      return ts.toString();
    } else {
      return "N/A";
    }
  }

  /// Builds a widget that shows "Followed By #X: <username>".
  /// If `userId` is blank or "N/A", it just shows "N/A".
  /// Otherwise, it fetches the user doc from "users/<userId>" and displays the name.
  Widget _buildFollowedByPerson(BuildContext context, String userId, int index) {
    // If the stored value is empty or "N/A", display that we have no user.
    if (userId.isEmpty || userId == "N/A") {
      return Text("Followed By #$index: N/A", style: TextStyle(fontSize: 16));
    }

    // Otherwise, look up the user doc for a first/last name.
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("Followed By #$index: Loading...",
              style: TextStyle(fontSize: 16));
        }
        if (snapshot.hasError) {
          return Text("Followed By #$index: Error",
              style: TextStyle(fontSize: 16, color: Colors.red));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Text("Followed By #$index: Unknown User (not found)",
              style: TextStyle(fontSize: 16));
        }

        // Extract user data
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final firstName = userData["firstName"]?.toString() ?? "";
        final lastName = userData["lastName"]?.toString() ?? "";
        final email = userData["email"]?.toString() ?? "";

        // Build a nice display name from first/last or fallback to email
        String displayName = (firstName + " " + lastName).trim();
        if (displayName.isEmpty) {
          displayName = email.isNotEmpty ? email : "Unnamed User";
        }

        return Text("Followed By #$index: $displayName",
            style: TextStyle(fontSize: 16));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Curative Ticket Details"),
        backgroundColor: Color(0xFF003366),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('curative_maintenance_tickets')
            .doc(ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text("No details found for Ticket ID: $ticketId"),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // Basic fields
          final String ticketTitle = data["ticketTitle"] ?? "Untitled Ticket";
          final String incidentDateStr = _formatTimestamp(data["incidentDateTime"]);
          final String issue = data["issue"] ?? "No issue info";
          final String line = data["line"] ?? "N/A";
          final String localOperator = data["localOperator"] ?? "N/A";
          final bool equipmentStopped = data["equipmentStopped"] ?? false;
          final bool psaStopped = data["psaStopped"] ?? false;
          final bool underWarranty = data["underWarranty"] ?? false;

          // Equipment Info
          final String equipmentBrand = data["equipmentBrand"] ?? "";
          final String equipmentModel = data["equipmentModel"] ?? "";
          final String equipmentName = data["equipmentName"] ?? "";
          final String equipmentID = data["equipmentID"] ?? "";
          final String selectedSparePart = data["selectedSparePart"] ?? "N/A";

          // Project/PSA/Site Info
          final String projectNumber = data["projectNumber"] ?? "N/A";
          final String siteName = data["siteName"] ?? "N/A";
          final String psaReference = data["psaReference"] ?? "N/A";
          final String Afrimed_projectId = data["Afrimed_projectId"] ?? "";

          // Timestamps
          final String createdAt = _formatTimestamp(data["createdAt"]);
          final String estimatedEndingDate =
          _formatTimestamp(data["estimatedEndingDate"]);

          // People / follow-up
          final String taskFollow1 = data["taskToBeFollowedByPerson1"] ?? "N/A";
          final String taskFollow2 = data["taskToBeFollowedByPerson2"] ?? "N/A";
          final String ticketCreatedBy = data["ticketCreatedBy"] ?? "N/A";

          // Pictures
          final List pictureList = data["pictureList"] ?? [];

          // Additional info
          final String notes = data["notes"] ?? "";
          final String imageUrl = data["imageUrl"] ?? "";

          // Build a combined equipment reference for display
          String equipmentFullRef = "";
          if (equipmentBrand.isNotEmpty ||
              equipmentModel.isNotEmpty ||
              equipmentID.isNotEmpty) {
            equipmentFullRef =
            "$equipmentBrand $equipmentModel (ID: $equipmentID)";
          }
          if (equipmentFullRef.trim().isEmpty && equipmentName.isNotEmpty) {
            equipmentFullRef = equipmentName;
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ticket Title
                    Text(
                      ticketTitle,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Divider(thickness: 1, height: 24),

                    // Project and Ticket Info
                    Text("Project: $projectNumber", style: TextStyle(fontSize: 16)),
                    Text("Afrimed Project ID: $Afrimed_projectId",
                        style: TextStyle(fontSize: 16)),
                    Text("Site: $siteName", style: TextStyle(fontSize: 16)),
                    Text("Line: $line", style: TextStyle(fontSize: 16)),
                    Text("PSA Reference: $psaReference", style: TextStyle(fontSize: 16)),

                    SizedBox(height: 8),

                    // Timestamps
                    Text("Created At: $createdAt", style: TextStyle(fontSize: 16)),
                    Text("Estimated Ending: $estimatedEndingDate",
                        style: TextStyle(fontSize: 16)),
                    Text("Incident Date: $incidentDateStr",
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),

                    // People Info
                    Text("Ticket Created By: $ticketCreatedBy",
                        style: TextStyle(fontSize: 16)),
                    // Instead of showing ID, we show the actual name(s):
                    _buildFollowedByPerson(context, taskFollow1, 1),
                    _buildFollowedByPerson(context, taskFollow2, 2),
                    SizedBox(height: 8),

                    // Equipment Info
                    Text("Equipment: $equipmentFullRef",
                        style: TextStyle(fontSize: 16)),
                    if (equipmentID.isNotEmpty)
                      Text("Equipment ID: $equipmentID",
                          style: TextStyle(fontSize: 16)),
                    Text("Spare Part: $selectedSparePart",
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),

                    // Boolean Fields
                    Text("Equipment Stopped? ${equipmentStopped ? 'Yes' : 'No'}",
                        style: TextStyle(fontSize: 16)),
                    Text("PSA Stopped? ${psaStopped ? 'Yes' : 'No'}",
                        style: TextStyle(fontSize: 16)),
                    Text("Under Warranty? ${underWarranty ? 'Yes' : 'No'}",
                        style: TextStyle(fontSize: 16)),
                    Divider(thickness: 1, height: 24),

                    // Additional Details
                    Text("Local Operator: $localOperator",
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 4),
                    Text("Issue:",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(issue, style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),

                    // PictureList
                    if (pictureList.isNotEmpty) ...[
                      Text("Pictures/Comments:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      for (var pic in pictureList)
                        if (pic is Map<String, dynamic>) ...[
                          if (pic["imageUrl"] != null &&
                              pic["imageUrl"].toString().isNotEmpty)
                            Image.network(
                              pic["imageUrl"],
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          if (pic["comment"] != null &&
                              pic["comment"].toString().isNotEmpty)
                            Text("Comment: ${pic["comment"]}",
                                style: TextStyle(fontSize: 14)),
                          SizedBox(height: 8),
                        ],
                    ],

                    // Additional Notes
                    if (notes.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text("Notes:",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(notes, style: TextStyle(fontSize: 16)),
                    ],

                    SizedBox(height: 16),

                    // Download Report Button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _downloadReport,
                        icon: Icon(Icons.download_outlined),
                        label: Text("Download Initial operator Report"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
