import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'preventive_maintenance_progress_page.dart';

class PreventiveMaintenanceDetailsPage extends StatefulWidget {
  final String calendarId;

  const PreventiveMaintenanceDetailsPage({
    Key? key,
    required this.calendarId,
  }) : super(key: key);

  @override
  _PreventiveMaintenanceDetailsPageState createState() =>
      _PreventiveMaintenanceDetailsPageState();
}

class _PreventiveMaintenanceDetailsPageState
    extends State<PreventiveMaintenanceDetailsPage> {
  // ---------- state ----------
  List<Map<String, dynamic>> scheduleDates = [];
  bool isLoading = true;

  /// Set of keys “yyyy-MM-dd” that already have ≥1 progress doc
  Set<String> _reportedDateKeys = {};

  // ---------- life-cycle ----------
  @override
  void initState() {
    super.initState();
    _fetchCalendarDetails();
  }

  // ---------- Firestore  ----------
  /// 1) main calendar doc
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

      final rawList = data['scheduleDates'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> newList = [];

      for (var item in rawList) {
        if (item is Timestamp) {
          newList.add({
            'originalDate': item,
            'date'        : item,
            'modified'    : false,
            'reason'      : '',
          });
        } else if (item is Map<String, dynamic>) {
          final ts        = item['date']         as Timestamp?;
          final original  = item['originalDate'] as Timestamp? ?? ts;
          final modified  = item['modified']     as bool?      ?? false;
          final reason    = item['reason']       as String?    ?? '';
          if (ts != null) {
            newList.add({
              'originalDate': original,
              'date'        : ts,
              'modified'    : modified,
              'reason'      : reason,
            });
          }
        }
      }

      setState(() {
        scheduleDates = newList;
        isLoading     = false;
      });

      await _fetchReportedDates();      // fetch progress list
    } catch (e) {
      debugPrint('Error fetching calendar details: $e');
      setState(() => isLoading = false);
    }
  }

  /// 2) gather all reported dates
  Future<void> _fetchReportedDates() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(widget.calendarId)
          .collection('progress')
          .get();

      final keys = <String>{};
      for (final p in snap.docs) {
        final ts = p['scheduledDate'] as Timestamp?;
        if (ts != null) {
          keys.add(DateFormat('yyyy-MM-dd').format(ts.toDate()));
        }
      }
      setState(() => _reportedDateKeys = keys);
    } catch (e) {
      debugPrint('Error fetching reported dates: $e');
    }
  }

  // ---------- edit single date ----------
  Future<void> _editScheduledDate(int index) async {
    final oldItem = scheduleDates[index];
    final oldDate = (oldItem['date'] as Timestamp).toDate();

    final picked = await showDatePicker(
      context: context,
      initialDate: oldDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked == null || picked == oldDate) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (_) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reason for date change'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Enter reason…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (reason == null) return;

    setState(() {
      scheduleDates[index]['date']     = Timestamp.fromDate(picked);
      scheduleDates[index]['modified'] = true;
      scheduleDates[index]['reason']   = reason;
    });
    await FirebaseFirestore.instance
        .collection('preventive_maintenance')
        .doc(widget.calendarId)
        .update({'scheduleDates': scheduleDates});
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Details'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : scheduleDates.isEmpty
          ? const Center(child: Text('No scheduled dates found.'))
          : ListView.builder(
        itemCount: scheduleDates.length,
        itemBuilder: (context, index) {
          final item         = scheduleDates[index];
          final tsCurrent    = item['date']     as Timestamp;
          final isModified   = item['modified'] as bool? ?? false;
          final reason       = item['reason']   as String? ?? '';
          final currentDate  = tsCurrent.toDate();
          final dateKey      = DateFormat('yyyy-MM-dd').format(currentDate);

          //---------------- label ----------------
          String label;
          if (!isModified) {
            label =
            'Scheduled Date: ${DateFormat('yyyy-MM-dd').format(currentDate)}';
          } else {
            final tsOrig   = item['originalDate'] as Timestamp;
            final origDate = tsOrig.toDate();
            final origStr  =
            DateFormat('yyyy-MM-dd').format(origDate);
            final currStr  =
            DateFormat('yyyy-MM-dd').format(currentDate);
            label = reason.isNotEmpty
                ? 'Originally: $origStr, now: $currStr (reason: $reason)'
                : 'Originally: $origStr, now: $currStr (modified)';
          }

          //---------------- colour logic ----------------
          final today      = DateTime.now();
          final isPastDate = currentDate.isBefore(
            DateTime(today.year, today.month, today.day),
          );
          final hasReport  = _reportedDateKeys.contains(dateKey);

          Color textColor = Colors.black;   // default → upcoming
          if (isPastDate) {
            textColor = hasReport ? Colors.green : Colors.red;
            if (!hasReport) label = '$label – No report yet';
          }

          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
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
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PreventiveMaintenanceProgressPage(
                      calendarId   : widget.calendarId,
                      scheduledDate: currentDate,
                    ),
                  ),
                );
                // After returning, refresh report list & colours
                await _fetchReportedDates();
                setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}
