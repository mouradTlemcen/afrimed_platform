// File: lib/progress_images_page.dart
//
// If you see "Error loading image: [object ProgressEvent]"
// it usually means a CORS issue. Check your Firebase Storage CORS config.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProgressImagesPage extends StatelessWidget {
  final List<dynamic> pictures;

  const ProgressImagesPage({Key? key, required this.pictures}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attached Images"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: pictures.length,
        itemBuilder: (context, index) {
          final pic = pictures[index];
          final String picUrl = pic['imageUrl'] ?? "";
          final String uploadedBy = pic['uploadedBy'] ?? "Unknown";
          final String picComment = pic['comment'] ?? "";

          // Attempt to parse timestamp if available
          DateTime picDate = DateTime.now();
          if (pic['uploadedAt'] != null && pic['uploadedAt'] is Timestamp) {
            picDate = (pic['uploadedAt'] as Timestamp).toDate();
          }
          final String picTime = DateFormat('yyyy-MM-dd – kk:mm').format(picDate);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display the image with a loading spinner & error text
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        picUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            "Error loading image: $error",
                            style: const TextStyle(color: Colors.red),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text("Uploaded by: $uploadedBy", style: const TextStyle(fontSize: 14)),
                  Text("Uploaded on: $picTime", style: const TextStyle(fontSize: 14)),
                  if (picComment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Comment: $picComment",
                        style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
