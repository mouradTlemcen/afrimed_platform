// File: lib/displacement_history_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart'; // for date formatting
import 'add_displacement_page.dart';

class DisplacementHistoryPage extends StatelessWidget {
  final String userId;

  const DisplacementHistoryPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  // Function to launch Google Maps with the provided latitude and longitude.
  void _launchGoogleMaps(double latitude, double longitude) async {
    final url = 'https://www.google.com/maps?q=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  // Function to show a confirmation dialog before deletion.
  void _confirmDeletion(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Displacement'),
        content: const Text('Are you sure you want to delete this displacement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('displacements')
                  .doc(docId)
                  .delete();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Function to validate departure.
  void _validateDeparture(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validate Departure'),
        content: const Text('Confirm that you left at the estimated end date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('displacements')
                  .doc(docId)
                  .update({
                'departureValidated': true,
                'departureValidationDate': FieldValue.serverTimestamp(),
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Departure validated.')),
              );
            },
            child: const Text(
              'Validate',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  // Function to request an extension using a date picker and a reason.
  void _requestExtension(BuildContext context, String docId) {
    final TextEditingController reasonController = TextEditingController();
    DateTime? selectedNewEndDate;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Request Extension'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedNewEndDate = pickedDate;
                        });
                      }
                    },
                    child: Text(
                      selectedNewEndDate == null
                          ? 'Select New End Date'
                          : 'New End Date: ${DateFormat('yyyy-MM-dd').format(selectedNewEndDate!)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Extension',
                      hintText: 'Enter extension reason',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedNewEndDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a new end date.')),
                      );
                      return;
                    }
                    if (reasonController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a reason for extension.')),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .collection('displacements')
                        .doc(docId)
                        .update({
                      'extensionRequested': true,
                      'requestedExtensionNewEndDate': selectedNewEndDate,
                      'extensionRequestReason': reasonController.text.trim(),
                      'extensionRequestDate': FieldValue.serverTimestamp(),
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Extension request submitted.')),
                    );
                  },
                  child: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Convert various Firestore date formats to a readable string.
  String _formatDate(dynamic firestoreDate) {
    if (firestoreDate == null) return 'Not Defined';

    // If it's a Timestamp, convert to DateTime.
    if (firestoreDate is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(firestoreDate.toDate());
    }
    // If it's already a String, return it.
    if (firestoreDate is String) {
      return firestoreDate;
    }
    return 'Not Defined';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Displacement History'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('displacements')
            .orderBy('addedDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No displacements found.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            );
          }

          final displacements = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: displacements.length,
            itemBuilder: (context, index) {
              final doc = displacements[index];
              final data = doc.data() as Map<String, dynamic>;

              // Basic location info.
              final country = data['country'] ?? 'Unknown Country';
              final city = data['city'] ?? 'Unknown City';
              final location = "Country: $country\nCity: $city";

              // Original start/end date.
              final startDateString = _formatDate(data['startDate']);
              final endDateString = _formatDate(data['endDate']);

              // If an extension is requested, we have a new end date & reason.
              final hasExtensionRequested = data['extensionRequested'] == true;
              final newEndDateString = hasExtensionRequested
                  ? _formatDate(data['requestedExtensionNewEndDate'])
                  : null;
              final extensionReason = data['extensionRequestReason'] ?? '';

              // Additional displacement details.
              final details = data['details'] ?? 'No Details';
              final gpsLocation = data['gpsLocation'] as Map<String, dynamic>?;

              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row with location, GPS and Delete buttons.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18.0,
                                color: Color(0xFF003366),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              gpsLocation != null
                                  ? ElevatedButton.icon(
                                onPressed: () {
                                  final latitude = gpsLocation['latitude'];
                                  final longitude = gpsLocation['longitude'];
                                  _launchGoogleMaps(latitude, longitude);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0073E6),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8.0, horizontal: 12.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                icon: const Icon(Icons.map, size: 16),
                                label: const Text(
                                  'View GPS',
                                  style: TextStyle(fontSize: 14),
                                ),
                              )
                                  : const Text(
                                'No GPS',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _confirmDeletion(context, doc.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      Text(
                        'From: $startDateString',
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'To: $endDateString',
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black87,
                        ),
                      ),
                      // If a new end date is requested, show it.
                      if (hasExtensionRequested && newEndDateString != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8.0),
                            Text(
                              'New End Date: $newEndDateString',
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (extensionReason.isNotEmpty)
                              Text(
                                'Reason: $extensionReason',
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                      const SizedBox(height: 12.0),
                      const Text(
                        'Details:',
                        style: TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        details,
                        style: const TextStyle(
                          fontSize: 14.0,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 12.0),
                      // New action buttons: Validate Departure & Request Extension.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () => _validateDeparture(context, doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Validate Departure',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _requestExtension(context, doc.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8.0, horizontal: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: const Text(
                              'Request Extension',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDisplacementPage(userId: userId),
            ),
          );
        },
        backgroundColor: const Color(0xFF003366),
        child: const Icon(Icons.add),
      ),
    );
  }
}