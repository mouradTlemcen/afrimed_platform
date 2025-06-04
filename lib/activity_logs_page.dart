import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({Key? key}) : super(key: key);

  @override
  _ActivityLogsPageState createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  // Filter variables.
  String _filterUserId = "All";
  String _filterAction = "All";
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Dropdown options populated from logs.
  List<String> _userIds = ["All"];
  List<String> _actions = ["All"];

  // Map to store userId -> firstName.
  Map<String, String> _userFirstNames = {};

  @override
  void initState() {
    super.initState();
    _fetchDistinctFilters();
    _fetchUserFirstNames();
  }

  /// Fetch distinct user IDs and actions from the 'activity_logs' collection.
  Future<void> _fetchDistinctFilters() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('activity_logs').get();

    Set<String> userSet = {"All"};
    Set<String> actionSet = {"All"};

    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('userId')) {
        userSet.add(data['userId']);
      }
      if (data.containsKey('action')) {
        actionSet.add(data['action']);
      }
    }

    setState(() {
      _userIds = userSet.toList();
      _actions = actionSet.toList();
    });
  }

  /// Fetch all users from Firestore and map userId -> firstName.
  Future<void> _fetchUserFirstNames() async {
    QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('users').get();

    Map<String, String> userMap = {};
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      String firstName = data['firstName'] ?? "";
      // doc.id is presumably the user’s UID or a known key
      userMap[doc.id] = firstName;
    }

    setState(() {
      _userFirstNames = userMap;
    });
  }

  /// Build the Firestore query based on current filters.
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('activity_logs');

    // Filter by userId if not "All"
    if (_filterUserId != "All") {
      query = query.where('userId', isEqualTo: _filterUserId);
    }

    // Filter by action if not "All"
    if (_filterAction != "All") {
      query = query.where('action', isEqualTo: _filterAction);
    }

    // Filter by date range if set
    if (_filterStartDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: _filterStartDate);
    }
    if (_filterEndDate != null) {
      DateTime endOfDay = DateTime(
        _filterEndDate!.year,
        _filterEndDate!.month,
        _filterEndDate!.day,
        23,
        59,
        59,
        999,
      );
      query = query.where('timestamp', isLessThanOrEqualTo: endOfDay);
    }

    // Order by timestamp descending
    query = query.orderBy('timestamp', descending: true);

    return query;
  }

  /// Check if the current user is the admin (Mourad).
  bool _isCurrentUserAdmin() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    return userEmail?.toLowerCase() == "mourad.benosman@servymed.com";
  }

  /// Builds the filter UI (dropdowns, date pickers, reset button).
  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: const Text("Filters", style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // Row for user and action filters.
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _filterUserId,
                        decoration: const InputDecoration(
                          labelText: "User",
                          border: OutlineInputBorder(),
                        ),
                        items: _userIds.map((u) {
                          return DropdownMenuItem(
                            value: u,
                            // Show "All" if it's "All"; otherwise show firstName from map
                            child: Text(u == "All"
                                ? "All"
                                : (_userFirstNames[u] ?? u)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _filterUserId = val!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _filterAction,
                        decoration: const InputDecoration(
                          labelText: "Action",
                          border: OutlineInputBorder(),
                        ),
                        items: _actions.map((a) {
                          return DropdownMenuItem(
                            value: a,
                            child: Text(a),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _filterAction = val!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Row for date range filters.
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterStartDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _filterStartDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _filterStartDate == null
                                ? "Start Date: Any"
                                : "Start Date: ${_filterStartDate!.toLocal()}".split(' ')[0],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _filterEndDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _filterEndDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _filterEndDate == null
                                ? "End Date: Any"
                                : "End Date: ${_filterEndDate!.toLocal()}".split(' ')[0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Reset filters button.
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _filterUserId = "All";
                        _filterAction = "All";
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                    },
                    child: const Text("Reset Filters"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Non-admin users get "Access Denied"
    if (!_isCurrentUserAdmin()) {
      return Scaffold(
        appBar: AppBar(title: const Text("Activity Logs")),
        body: const Center(child: Text("Access Denied")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity Logs"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Column(
        children: [
          // The filter card at the top
          _buildFilterSection(),

          // The main body with the logs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery().snapshots(),
              builder: (context, snapshot) {
                // 1) If there's an error, show it
                if (snapshot.hasError) {
                  // 1) Print the raw `snapshot.error`
                  debugPrint('Stream error: ${snapshot.error}');

                  // 2) If it’s a FirebaseException, print more details
                  if (snapshot.error is FirebaseException) {
                    final firebaseErr = snapshot.error as FirebaseException;
                    debugPrint('code: ${firebaseErr.code}');
                    debugPrint('message: ${firebaseErr.message}');
                    debugPrint('stack: ${firebaseErr.stackTrace}');
                  }

                  // Show a basic error widget
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }


                // 2) Show loading spinner while waiting for data
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 3) If no data or docs
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No activity logs found."));
                }

                // 4) We have data; build the list
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final userId = data['userId'] ?? "Unknown User";
                    // Show user’s first name if available
                    final firstName = _userFirstNames[userId] ?? userId;
                    final action = data['action'] ?? "No Action";
                    final details = data['details'] ?? "";

                    // Parse timestamp
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    final timeStr = (ts != null)
                        ? ts.toDate().toString().split(".")[0]
                        : "No Timestamp";

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      child: ListTile(
                        title: Text("Action: $action"),
                        subtitle: Text(
                          "User: $firstName\nDetails: $details\nTime: $timeStr",
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
    );
  }
}
