import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TaskManagementDetailsPage extends StatefulWidget {
  final String projectId;
  final String taskId;
  final String taskTitle;

  TaskManagementDetailsPage({required this.projectId, required this.taskId, required this.taskTitle});

  @override
  _TaskManagementDetailsPageState createState() => _TaskManagementDetailsPageState();
}

class _TaskManagementDetailsPageState extends State<TaskManagementDetailsPage> {
  Map<String, dynamic>? taskData;

  @override
  void initState() {
    super.initState();
    _fetchTaskDetails();
  }

  // Fetch task details from Firestore
  void _fetchTaskDetails() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('tasks')
        .doc(widget.taskId)
        .get();

    setState(() {
      taskData = doc.data() as Map<String, dynamic>;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.taskTitle)),
      body: taskData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Task: ${taskData!["title"]}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Subtasks:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: taskData!["subtasks"].length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      title: Text(taskData!["subtasks"][index]),
                    ),
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
