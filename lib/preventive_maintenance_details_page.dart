import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'preventive_maintenance_progress_page.dart';

class PreventiveMaintenanceDetailsPage extends StatefulWidget {
  final String calendarId;
  const PreventiveMaintenanceDetailsPage({Key? key, required this.calendarId})
      : super(key: key);

  @override
  _PreventiveMaintenanceDetailsPageState createState() =>
      _PreventiveMaintenanceDetailsPageState();
}

class _PreventiveMaintenanceDetailsPageState
    extends State<PreventiveMaintenanceDetailsPage> {
  List<Map<String, dynamic>> scheduleDates = [];
  bool isLoading = true;

  /// We'll store whether the main doc has a non-empty finalPpmReportUrl
  String _finalUrl = '';
  bool _hasFinalUrl = false;

  @override
  void initState() {
    super.initState();
    _fetchCalendarDetails();
  }

  /// Fetch the main doc from Firestore => build scheduleDates list,
  /// also read finalPpmReportUrl from the same doc.
  Future<void> _fetchCalendarDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .get();

      if (!doc.exists) {
        setState(() => isLoading = false);
        return;
      }

      final data = doc.data() as Map<String, dynamic>? ?? {};

      // Read the finalUrl from the main doc
      _finalUrl = data['finalPpmReportUrl'] as String? ?? '';
      _hasFinalUrl = _finalUrl.isNotEmpty;

      final rawList = data['scheduleDates'] as List<dynamic>? ?? [];
      final newList = <Map<String, dynamic>>[];

      for (var item in rawList) {
        if (item is Timestamp) {
          // old shape
          newList.add({
            "originalDate": item,
            "date": item,
            "modified": false,
            "reason": "",
          });
        } else if (item is Map<String, dynamic>) {
          final ts = item["date"] as Timestamp?;
          if (ts == null) continue;
          final originalTs = item["originalDate"] as Timestamp? ?? ts;
          final modified = item["modified"] as bool? ?? false;
          final reason = item["reason"] as String? ?? "";
          newList.add({
            "originalDate": originalTs,
            "date": ts,
            "modified": modified,
            "reason": reason,
          });
        }
      }

      setState(() {
        scheduleDates = newList;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching calendar details: $e");
      setState(() => isLoading = false);
    }
  }

  /// Save updated scheduleDates to Firestore
  Future<void> _saveScheduleDatesToFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .update({'scheduleDates': scheduleDates});
    } catch (e) {
      debugPrint("Error saving updated dates: $e");
    }
  }

  /// Let user pick a new date + reason => store in 'date', keep 'originalDate'
  Future<void> _editScheduledDate(int index) async {
    final oldItem = scheduleDates[index];
    final oldDate = (oldItem["date"] as Timestamp).toDate();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: oldDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (pickedDate == null) return;

    if (pickedDate == oldDate) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        final reasonCtrl = TextEditingController();
        return AlertDialog(
          title: const Text("Reason for date change"),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(hintText: "Enter reason..."),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, reasonCtrl.text.trim());
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (reason == null) {
      return; // user canceled reason
    }

    setState(() {
      scheduleDates[index]["date"] = Timestamp.fromDate(pickedDate);
      scheduleDates[index]["modified"] = true;
      scheduleDates[index]["reason"] = reason;
    });
    await _saveScheduleDatesToFirestore();

    // If you want to also update a progress doc or do something else,
    // you can do it here. But for a single finalPpmReportUrl in the main doc,
    // there's nothing more to do.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendar Details"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (scheduleDates.isEmpty)
          ? const Center(child: Text("No scheduled dates found."))
          : ListView.builder(
        itemCount: scheduleDates.length,
        itemBuilder: (context, index) {
          final item = scheduleDates[index];
          final currentDateTs = item["date"] as Timestamp;
          final isModified = item["modified"] as bool? ?? false;
          final reason = item["reason"] as String? ?? "";
          final currentDate = currentDateTs.toDate();

          // If not modified, just display "Scheduled Date: XXX"
          // If modified, show original + reason
          String label;
          if (!isModified) {
            label = "Scheduled Date: "
                "${DateFormat('yyyy-MM-dd').format(currentDate)}";
          } else {
            final originalTs = item["originalDate"] as Timestamp;
            final originalDate = originalTs.toDate();
            final originalDateStr =
            DateFormat('yyyy-MM-dd').format(originalDate);
            final currentDateStr =
            DateFormat('yyyy-MM-dd').format(currentDate);
            label = reason.isNotEmpty
                ? "Originally: $originalDateStr, now: $currentDateStr (reason: $reason)"
                : "Originally: $originalDateStr, now: $currentDateStr (modified)";
          }

          // If date is in the past and there's NO final URL => red
          final now = DateTime.now();
          final isBeforeToday = currentDate.isBefore(
            DateTime(now.year, now.month, now.day),
          );

          Color textColor = Colors.black;
          if (isBeforeToday && !_hasFinalUrl) {
            textColor = Colors.red;
          }

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: ListTile(
              title: Text(label, style: TextStyle(color: textColor)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editScheduledDate(index),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward),
                ],
              ),
              onTap: () async {
                // If you want to open a "progress" page, you can do so,
                // but note that you're no longer reading or updating
                // any finalPpmReportUrl from the subcollection.
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreventiveMaintenanceProgressPage(
                      calendarId: widget.calendarId,
                      scheduledDate: currentDate,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
