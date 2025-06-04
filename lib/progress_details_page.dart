import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProgressDetailsPage extends StatelessWidget {
  final Map<String, dynamic> progressData;
  final String progressId;

  const ProgressDetailsPage({
    Key? key,
    required this.progressData,
    required this.progressId,
  }) : super(key: key);

  // ---------------------------------------------------------
  // 1) Helper method to fetch the user's full name from Firestore.
  //    (Used in the existing progress card)
  // ---------------------------------------------------------
  Future<String> _getUserName(String userId) async {
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
        return "Unknown";
      }
    } catch (e) {
      return "Unknown";
    }
  }

  // ---------------------------------------------------------
  // 2) NEW: Fetch the Task doc (from "tasks") & its project doc
  // ---------------------------------------------------------
  Future<Map<String, dynamic>?> _fetchTaskAndProject() async {
    final String? taskId = progressData["taskId"];
    if (taskId == null || taskId.isEmpty) {
      // No taskId in progressData => cannot fetch Task
      return null;
    }

    // Fetch the task doc
    final taskSnap = await FirebaseFirestore.instance
        .collection("tasks")
        .doc(taskId)
        .get();
    if (!taskSnap.exists) {
      return null;
    }

    final taskData = taskSnap.data() as Map<String, dynamic>;

    // If there's a projectId, we fetch the project doc to get "Afrimed_projectId"
    final String? projectDocId = taskData["projectId"];
    if (projectDocId != null && projectDocId.isNotEmpty) {
      final projectSnap = await FirebaseFirestore.instance
          .collection("projects")
          .doc(projectDocId)
          .get();
      if (projectSnap.exists) {
        final projectData = projectSnap.data() as Map<String, dynamic>;
        final afrimedProjectId = projectData["Afrimed_projectId"] ?? "(No Afrimed ProjectID)";
        // Attach it to the taskData for easy display
        taskData["afrimedProjectId"] = afrimedProjectId;
      } else {
        // If no project doc found, store placeholder
        taskData["afrimedProjectId"] = "(Unknown)";
      }
    } else {
      // If no projectId on the task, store placeholder
      taskData["afrimedProjectId"] = "(Unknown)";
    }

    return taskData;
  }

  @override
  Widget build(BuildContext context) {
    // ---------------------------------------------------------
    // Existing progress details (do NOT change your logic here)
    // ---------------------------------------------------------
    Timestamp ts = progressData['timestamp'];
    String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate());
    String text = progressData['text'] ?? "";
    bool afterDone = progressData['afterTaskDone'] == true;
    String userId = progressData['userId'] ?? "Unknown";
    String? picUrl = progressData['pictureUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Progress Details"),
        backgroundColor: Colors.blue[800],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------
            // FUTURE BUILDER: Show top-of-page Task info + Afrimed_projectId
            // ---------------------------------------------------------
            FutureBuilder<Map<String, dynamic>?>(
              future: _fetchTaskAndProject(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Text("Loading task info...");
                } else if (snapshot.hasError) {
                  return Text("Error loading task info: ${snapshot.error}");
                }

                final taskData = snapshot.data;
                if (taskData == null) {
                  return const Text(
                    "No Task data found (maybe no taskId).",
                    style: TextStyle(color: Colors.red),
                  );
                }

                // Extract fields from the Task doc
                final title = taskData["title"] ?? "";
                final assignedTo = taskData["assignedTo"] ?? "";
                final createdAtTs = taskData["createdAt"] as Timestamp?;
                final createdAtStr = (createdAtTs != null)
                    ? DateFormat('yyyy-MM-dd HH:mm').format(createdAtTs.toDate())
                    : "(No date)";
                final createdByName = taskData["createdByName"] ?? "";
                final description = taskData["description"] ?? "";
                final startTs = taskData["startingDate"] as Timestamp?;
                final startingDateStr = (startTs != null)
                    ? DateFormat('yyyy-MM-dd').format(startTs.toDate())
                    : "(No date)";
                final endTs = taskData["endingDate"] as Timestamp?;
                final endingDateStr = (endTs != null)
                    ? DateFormat('yyyy-MM-dd').format(endTs.toDate())
                    : "(No date)";

                final phase = taskData["phase"] ?? "";
                final priority = taskData["priority"] ?? "";
                final site = taskData["site"] ?? "";
                final status = taskData["status"] ?? "";
                final taskType = taskData["taskType"] ?? "";
                final afrimedProjectId = taskData["afrimedProjectId"] ?? "";

                // Return a card with these fields
                return Card(
                  color: Colors.white70,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Title: $title",
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Assigned To: $assignedTo"),
                        Text("Created At: $createdAtStr"),
                        Text("Created By: $createdByName"),
                        Text("Description: $description"),
                        Text("Starting Date: $startingDateStr"),
                        Text("Ending Date: $endingDateStr"),
                        Text("Phase: $phase"),
                        Text("Priority: $priority"),
                        Text("Project ID (Afrimed): $afrimedProjectId"),
                        Text("Site: $site"),
                        Text("Status: $status"),
                        Text("Task Type: $taskType"),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ---------------------------------------------------------
            // Your existing progress card (unchanged)
            // ---------------------------------------------------------
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Date: $dateStr",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    FutureBuilder<String>(
                      future: _getUserName(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text("Loading user...");
                        } else if (snapshot.hasError) {
                          return const Text("Error loading user");
                        } else {
                          return Text("Written by: ${snapshot.data}",
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic, fontSize: 16));
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text("Progress:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      text + (afterDone ? " (added after completion)" : ""),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (picUrl != null && picUrl.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Attached Image:",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Image.network(picUrl),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
