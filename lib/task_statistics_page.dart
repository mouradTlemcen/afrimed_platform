import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Add the fl_chart import:
import 'package:fl_chart/fl_chart.dart';

class TaskStatisticsPage extends StatefulWidget {
  @override
  _TaskStatisticsPageState createState() => _TaskStatisticsPageState();
}

class _TaskStatisticsPageState extends State<TaskStatisticsPage> {
  DateTime? periodStart;
  DateTime? periodEnd;
  bool isLoading = false;

  // Basic counters
  int totalTasks = 0;
  Map<String, int> statusCounts = {};

  // By user
  Map<String, int> tasksByUser = {};
  Map<String, int> completedTasksByUser = {};
  Map<String, Duration> totalCompletionTimesByUser = {};

  // Mapping of userId -> user name
  Map<String, String> userNames = {};

  // For daily counts
  // dayString -> number of tasks created that day
  Map<String, int> tasksCreatedPerDay = {};
  // dayString -> number of tasks completed that day
  Map<String, int> tasksCompletedPerDay = {};

  @override
  void initState() {
    super.initState();
    // Default period: last 7 days
    periodStart = DateTime.now().subtract(const Duration(days: 7));
    periodEnd = DateTime.now();
    _fetchStatistics();
  }

  // ----------------------------------------------------
  // Fetch data from Firestore and compute statistics
  // ----------------------------------------------------
  Future<void> _fetchStatistics() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1) Fetch tasks
      QuerySnapshot tasksSnapshot =
      await FirebaseFirestore.instance.collection('tasks').get();
      List tasksDocs = tasksSnapshot.docs;

      // 2) Fetch users (to build userNames map)
      QuerySnapshot usersSnapshot =
      await FirebaseFirestore.instance.collection('users').get();

      userNames = {};
      for (var userDoc in usersSnapshot.docs) {
        var data = userDoc.data() as Map<String, dynamic>;
        String name =
        ((data['firstName'] ?? '') + ' ' + (data['lastName'] ?? '')).trim();
        if (name.isEmpty) name = "Unknown";
        userNames[userDoc.id] = name;
      }

      // 3) Filter tasks by date range if both periodStart & periodEnd are set
      List filteredTasks = tasksDocs;
      if (periodStart != null && periodEnd != null) {
        filteredTasks = tasksDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['createdAt'] == null) return false;
          DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
          return !createdAt.isBefore(periodStart!) &&
              !createdAt.isAfter(periodEnd!);
        }).toList();
      }

      // Reset local counters
      totalTasks = filteredTasks.length;
      statusCounts = {};
      tasksByUser = {};
      completedTasksByUser = {};
      totalCompletionTimesByUser = {};
      tasksCreatedPerDay = {};
      tasksCompletedPerDay = {};

      // 4) Process each task
      for (var doc in filteredTasks) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // ---- Status
        String status = data["status"] ?? "Unknown";
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;

        // ---- By user
        String userId = data["assignedTo"] ?? "Unassigned";
        tasksByUser[userId] = (tasksByUser[userId] ?? 0) + 1;

        // ---- Timestamps
        DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
        String dayCreatedString = DateFormat('yyyy-MM-dd').format(createdAt);
        tasksCreatedPerDay[dayCreatedString] =
            (tasksCreatedPerDay[dayCreatedString] ?? 0) + 1;

        // If completed, compute completed date & durations
        if (status == "Done In Time" || status == "Done After Deadline") {
          if (data["lastProgressAt"] != null) {
            DateTime completedAt =
            (data["lastProgressAt"] as Timestamp).toDate();
            // Count completions per day
            String dayCompletedString =
            DateFormat('yyyy-MM-dd').format(completedAt);
            tasksCompletedPerDay[dayCompletedString] =
                (tasksCompletedPerDay[dayCompletedString] ?? 0) + 1;

            // For average completion time
            Duration diff = completedAt.difference(createdAt);
            totalCompletionTimesByUser[userId] =
                (totalCompletionTimesByUser[userId] ?? Duration.zero) + diff;

            completedTasksByUser[userId] =
                (completedTasksByUser[userId] ?? 0) + 1;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching statistics: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  // ----------------------------------------------------
  // UI Builders
  // ----------------------------------------------------
  Widget _buildPeriodPicker() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Start Date
            Expanded(
              child: InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: periodStart ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      periodStart = picked;
                    });
                  }
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(periodStart == null
                      ? "Start Date"
                      : DateFormat('yyyy-MM-dd').format(periodStart!)),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // End Date
            Expanded(
              child: InkWell(
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: periodEnd ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      periodEnd = picked;
                    });
                  }
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(periodEnd == null
                      ? "End Date"
                      : DateFormat('yyyy-MM-dd').format(periodEnd!)),
                ),
              ),
            ),
            const SizedBox(width: 16),

            ElevatedButton(
              onPressed: _fetchStatistics,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
              ),
              child: const Text("Filter"),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Summary Card (Total Tasks + Status counts)
  // ----------------------------------------------------
  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Tasks: $totalTasks",
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Tasks by Status:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...statusCounts.entries.map((entry) {
              return Text("${entry.key}: ${entry.value}",
                  style: const TextStyle(fontSize: 16));
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Pie Chart for status distribution
  // ----------------------------------------------------
  Widget _buildStatusPieChart() {
    if (statusCounts.isEmpty) {
      return const Center(child: Text("No status data."));
    }

    // Convert statusCounts to PieChart sections
    // E.g. each status is a slice
    final total = statusCounts.values.fold(0, (a, b) => a + b);

    // We'll pick some random colors or you can define them
    final colorPalette = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
    ];

    int colorIndex = 0;
    final sections = <PieChartSectionData>[];
    statusCounts.forEach((status, count) {
      final double percentage = (count / total) * 100;
      // Keep colorIndex in range
      final color = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;

      sections.add(
        PieChartSectionData(
          color: color,
          value: count.toDouble(),
          title: "${percentage.toStringAsFixed(1)}%",
          radius: 50,
          showTitle: true,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    });

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            "Task Status Distribution",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: statusCounts.keys.map((status) {
              // We rely on the same color index logic to keep them matched
              final idx = statusCounts.keys.toList().indexOf(status);
              final color = colorPalette[idx % colorPalette.length];
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 14, height: 14, color: color),
                  const SizedBox(width: 6),
                  Text(status),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Chart: Created & Completed tasks by day (line chart)
  // ----------------------------------------------------
  Widget _buildTasksByDayLineChart() {
    // Sort the days chronologically
    final allDays = <String>{};
    allDays.addAll(tasksCreatedPerDay.keys);
    allDays.addAll(tasksCompletedPerDay.keys);
    final sortedDays = allDays.toList();
    sortedDays.sort((a, b) => a.compareTo(b));

    if (sortedDays.isEmpty) {
      return const Center(child: Text("No daily data."));
    }

    // We'll build two line chart data sets:
    // 1) tasksCreated
    // 2) tasksCompleted
    final createdSpots = <FlSpot>[];
    final completedSpots = <FlSpot>[];

    for (int i = 0; i < sortedDays.length; i++) {
      final dayStr = sortedDays[i];
      final createdCount = tasksCreatedPerDay[dayStr] ?? 0;
      final completedCount = tasksCompletedPerDay[dayStr] ?? 0;
      createdSpots.add(FlSpot(i.toDouble(), createdCount.toDouble()));
      completedSpots.add(FlSpot(i.toDouble(), completedCount.toDouble()));
    }

    // We'll show the X axis as day indexes, but show a label with the day string
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Column(
          children: [
            const Text(
              "Tasks Created vs Completed by Day",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: sortedDays.length - 1.toDouble(),
                  minY: 0,
                  // Let maxY auto-scale based on data
                  lineBarsData: [
                    LineChartBarData(
                      spots: createdSpots,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      color: Colors.blue,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                    LineChartBarData(
                      spots: completedSpots,
                      isCurved: true,
                      dotData: FlDotData(show: false),
                      color: Colors.green,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withOpacity(0.2),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        // Show the day string, but might abbreviate
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedDays.length) {
                            return const SizedBox.shrink();
                          }
                          // Example: "MM-dd"
                          final dayStr = sortedDays[index].substring(5);
                          return Text(
                            dayStr,
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      left: BorderSide(color: Colors.black12),
                      bottom: BorderSide(color: Colors.black12),
                      right: BorderSide(color: Colors.transparent),
                      top: BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // A little legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLineLegend(color: Colors.blue, label: "Created"),
                const SizedBox(width: 16),
                _buildLineLegend(color: Colors.green, label: "Completed"),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLineLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }

  // ----------------------------------------------------
  // Tasks by Person Table
  // ----------------------------------------------------
  Widget _buildTasksByPersonTable() {
    List<DataRow> rows = [];
    tasksByUser.forEach((userId, count) {
      String userName = userNames[userId] ?? userId;
      int completed = completedTasksByUser[userId] ?? 0;

      String avgTime = "-";
      if (completed > 0) {
        Duration totalTime =
            totalCompletionTimesByUser[userId] ?? Duration.zero;
        Duration avg = totalTime ~/ completed;
        avgTime = "${avg.inHours}h ${avg.inMinutes.remainder(60)}m";
      }

      rows.add(
        DataRow(
          cells: [
            DataCell(Text(userName, style: const TextStyle(fontSize: 14))),
            DataCell(Text(count.toString(),
                style: const TextStyle(fontSize: 14))),
            DataCell(Text(completed.toString(),
                style: const TextStyle(fontSize: 14))),
            DataCell(Text(avgTime, style: const TextStyle(fontSize: 14))),
          ],
        ),
      );
    });

    if (rows.isEmpty) {
      return const Text("No users or tasks found in this period.");
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
        MaterialStateProperty.all(Colors.blue.shade800),
        headingTextStyle:
        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        columns: const [
          DataColumn(label: Text("User")),
          DataColumn(label: Text("Total Tasks")),
          DataColumn(label: Text("Completed")),
          DataColumn(label: Text("Avg Completion Time")),
        ],
        rows: rows,
      ),
    );
  }

  // ----------------------------------------------------
  // Build Method
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Task Statistics"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _fetchStatistics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Filter
              _buildPeriodPicker(),
              // Summary
              _buildSummaryCard(),

              // Pie Chart: distribution by status
              _buildStatusPieChart(),

              // Line chart: tasks created vs completed
              _buildTasksByDayLineChart(),

              // Tasks by Person
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  "Tasks by Person",
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTasksByPersonTable(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
