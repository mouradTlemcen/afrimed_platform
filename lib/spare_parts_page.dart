import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SparePartsPage extends StatefulWidget {
  @override
  _SparePartsPageState createState() => _SparePartsPageState();
}

class _SparePartsPageState extends State<SparePartsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spare Parts Inventory'),
        backgroundColor: const Color(0xFF003366), // Navy Blue
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('spare_parts').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No spare parts found.'));
          }

          final spareParts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: spareParts.length,
            itemBuilder: (context, index) {
              final data = spareParts[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(data['partName'] ?? 'Unknown Part'),
                  subtitle: Text('Quantity: ${data['quantityAvailable'] ?? '0'}'),
                  trailing: Icon(Icons.arrow_forward),
                  onTap: () {
                    // Navigate to spare part details
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
