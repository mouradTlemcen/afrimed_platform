import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'add_preventive_maintenance_calendar_page.dart';
import 'preventive_maintenance_details_page.dart';

class PreventiveMaintenancePage extends StatefulWidget {
  @override
  _PreventiveMaintenancePageState createState() =>
      _PreventiveMaintenancePageState();
}

class _PreventiveMaintenancePageState extends State<PreventiveMaintenancePage> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preventive Maintenance Calendars"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Column(
        children: [
          // Search filter
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: "Search Calendars",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // List of Calendars
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('preventive_maintenance')
                  .orderBy('startDate', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No preventive maintenance calendars scheduled."),
                  );
                }

                final calendars = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title =
                      data['calendarTitle']?.toString().toLowerCase() ?? '';
                  return title.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: calendars.length,
                  itemBuilder: (context, index) {
                    final calendarDoc = calendars[index];
                    final data = calendarDoc.data() as Map<String, dynamic>;
                    final calendarId = calendarDoc.id;

                    final calendarTitle =
                        data['calendarTitle'] ?? 'Untitled Calendar';
                    final projectNumber =
                        data['projectNumber'] ?? 'UnknownProjectDocId';
                    final siteName = data['site'] ?? 'Global';
                    final psaReference = data['psaReference'] ?? 'No PSA';

                    // We'll parse start/end for display
                    final Timestamp? tsStart = data['startDate'] as Timestamp?;
                    final Timestamp? tsEnd = data['endDate'] as Timestamp?;
                    final fromDate = (tsStart != null)
                        ? DateFormat('yyyy-MM-dd').format(tsStart.toDate())
                        : 'N/A';
                    final toDate = (tsEnd != null)
                        ? DateFormat('yyyy-MM-dd').format(tsEnd.toDate())
                        : 'N/A';

                    // Instead of a subcollection check, we do a FutureBuilder
                    // to see if there's any past date while main doc's finalPpmReportUrl is empty.
                    return FutureBuilder<bool>(
                      future: _checkAnyDateOverdueWithoutFinal(calendarId),
                      builder: (context, snapCheck) {
                        if (snapCheck.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final bool isCalendarOverdue = snapCheck.data == true;

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          // If the calendar is overdue => color the entire card
                          color: isCalendarOverdue ? Colors.red.shade100 : Colors.white,
                          child: ListTile(
                            title: Text(
                              calendarTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCalendarOverdue ? Colors.red : Colors.black,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Site: $siteName",
                                  style: TextStyle(
                                    color:
                                    isCalendarOverdue ? Colors.red : Colors.black,
                                  ),
                                ),
                                Text("PSA Reference: $psaReference"),
                                Text("From: $fromDate   To: $toDate"),
                              ],
                            ),
                            onTap: () {
                              // Go to details page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PreventiveMaintenanceDetailsPage(
                                        calendarId: calendarId,
                                      ),
                                ),
                              );
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Delete Calendar"),
                                    content: const Text(
                                        "Are you sure you want to delete this calendar?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('preventive_maintenance')
                                      .doc(calendarId)
                                      .delete();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Calendar deleted successfully.")
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the page to add a new calendar
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddPreventiveMaintenanceCalendarPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Checks if this calendar has ANY date in the past while finalPpmReportUrl is empty.
  Future<bool> _checkAnyDateOverdueWithoutFinal(String calendarId) async {
    try {
      // 1) fetch the main doc
      final docSnap = await FirebaseFirestore.instance
          .collection('preventive_maintenance')
          .doc(calendarId)
          .get();
      if (!docSnap.exists) return false;

      final data = docSnap.data() as Map<String, dynamic>? ?? {};
      final finalUrl = data['finalPpmReportUrl'] as String? ?? '';
      final bool hasFinalUrl = finalUrl.isNotEmpty;

      // If the doc DOES have a final report, it's never overdue.
      // (Because you told us you only want 1 final url in the main doc.)
      if (hasFinalUrl) {
        return false;
      }

      // 2) parse the scheduleDates
      final rawList = data['scheduleDates'] as List<dynamic>? ?? [];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final dateList = <DateTime>[];
      for (var item in rawList) {
        if (item is Timestamp) {
          dateList.add(item.toDate());
        } else if (item is Map<String, dynamic>) {
          final ts = item['date'] as Timestamp?;
          if (ts != null) dateList.add(ts.toDate());
        }
      }

      // 3) If ANY date is already in the past, but we have no final URL => overdue
      for (final d in dateList) {
        if (d.isBefore(today)) {
          return true; // found a date in the past, no final URL => overdue
        }
      }

      // No date is in the past => not overdue
      return false;
    } catch (e) {
      debugPrint("Error in _checkAnyDateOverdueWithoutFinal($calendarId): $e");
      return false;
    }
  }
}
