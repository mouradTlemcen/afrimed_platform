import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// Import the page you’ll navigate to when viewing training progress
// e.g., import 'training_progress_page.dart';

import 'displacement_history_page.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // For picking profile images
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImageFile;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  // --- Fetch the user document from Firestore ---
  void fetchUserData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // --- Pick a new profile picture from the gallery ---
  Future<void> _pickProfilePicture() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = pickedFile;
      });
      _uploadProfilePicture();
    }
  }

  // --- Upload the profile picture to Firebase Storage ---
  Future<void> _uploadProfilePicture() async {
    if (_profileImageFile == null) return;
    try {
      String fileName =
          "${widget.userId}_profile_${DateTime.now().millisecondsSinceEpoch}";
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("profilePictures")
          .child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        Uint8List fileBytes = await _profileImageFile!.readAsBytes();
        snapshot = await storageRef.putData(fileBytes);
      } else {
        File localFile = File(_profileImageFile!.path);
        snapshot = await storageRef.putFile(localFile);
      }
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update the Firestore user document with the new profile image URL.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'profileImageUrl': downloadUrl});

      // Reload user data to reflect the change.
      fetchUserData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated successfully!")),
      );
    } catch (e) {
      print("Error uploading profile picture: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading profile picture: $e")),
      );
    }
  }

  // --- Helper widget for a label-value row ---
  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value.isNotEmpty ? value : "N/A"),
          ),
        ],
      ),
    );
  }

  // --- Helper widget for a card section title ---
  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- Helper widget to display a list of expertise as chips ---
  Widget buildExpertiseChips(List<dynamic>? expertiseList) {
    if (expertiseList == null || expertiseList.isEmpty) {
      return const Text("N/A");
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: expertiseList
          .map((item) => Chip(label: Text(item.toString())))
          .toList(),
    );
  }

  // --- Helper widget for the CV download button ---
  Widget buildCVSection(String? cvUrl) {
    if (cvUrl == null || cvUrl.isEmpty) {
      return buildInfoRow("CV Document", "No CV uploaded");
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSectionTitle("CV Document"),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text("Download CV"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0073E6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final Uri url = Uri.parse(cvUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Could not launch $cvUrl")),
                );
              }
            },
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (userData == null)
          ? const Center(child: Text("No data available."))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- Profile Picture Section ---
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: userData!['profileImageUrl'] != null
                        ? NetworkImage(userData!['profileImageUrl'])
                        : null,
                    child: userData!['profileImageUrl'] == null
                        ? const Icon(
                      Icons.person,
                      size: 52,
                      color: Colors.white,
                    )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _pickProfilePicture,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).primaryColor,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- BASIC INFO CARD ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle("Basic Information"),
                    buildInfoRow(
                      "Full Name",
                      "${userData!['firstName'] ?? ''} ${userData!['lastName'] ?? ''}",
                    ),
                    buildInfoRow("Email", userData!['email'] ?? ''),
                    buildInfoRow("Phone", userData!['phone'] ?? ''),
                    buildInfoRow("Date of Birth", userData!['dateOfBirth'] ?? ''),
                    buildInfoRow("Gender", userData!['gender'] ?? ''),
                    buildInfoRow("Address", userData!['address'] ?? ''),
                  ],
                ),
              ),
            ),

            // --- WORK INFO CARD ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle("Work Information"),
                    buildInfoRow("Department", userData!['department'] ?? ''),
                    buildInfoRow("Position", userData!['position'] ?? ''),
                    buildInfoRow("Employment Type", userData!['employmentType'] ?? ''),
                    buildInfoRow(
                      "Monthly Salary",
                      (userData!['agreedMonthlySalary'] ?? '').toString(),
                    ),
                    buildInfoRow("Start Date", userData!['startDate'] ?? ''),
                    buildInfoRow("Employee ID", userData!['employeeID'] ?? ''),
                    buildInfoRow("Has Tasks", userData!['has_tasks'] ?? 'N/A'),
                  ],
                ),
              ),
            ),

            // --- MISSION STATUS CARD ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle("Mission Status"),
                    buildInfoRow("Online Mission",
                        userData!['onlineMissionStatus'] ?? 'N/A'),
                    buildInfoRow("Field Mission",
                        userData!['fieldMissionStatus'] ?? 'N/A'),
                  ],
                ),
              ),
            ),

            // --- EXPERTISE CARD ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle("Domains of Expertise"),
                    buildExpertiseChips(userData!['domainsOfExpertise']),
                  ],
                ),
              ),
            ),

            // --- CV CARD (with Download Button) ---
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: buildCVSection(userData!['cvUrl']),
              ),
            ),

            // --- ACTION BUTTONS: DISPLACEMENT & TRAINING ---
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // View Displacement History Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DisplacementHistoryPage(userId: widget.userId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text("Displacement History"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                // View Training Progress Button
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navigate to your training progress page
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => TrainingProgressPage(userId: widget.userId),
                    //   ),
                    // );
                  },
                  icon: const Icon(Icons.school),
                  label: const Text("Training Progress"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0073E6),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
