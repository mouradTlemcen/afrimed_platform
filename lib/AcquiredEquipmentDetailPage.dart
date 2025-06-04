import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AcquiredEquipmentDetailPage extends StatelessWidget {
  final String documentId;
  final Map<String, dynamic> data;

  const AcquiredEquipmentDetailPage({
    Key? key,
    required this.documentId,
    required this.data,
  }) : super(key: key);

  Future<void> _openFileUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Existing fields
    final type = data['equipmentType'] ?? 'N/A';
    final brand = data['brand'] ?? 'N/A';
    final model = data['model'] ?? 'N/A';
    final serial = data['serialNumber'] ?? 'N/A';
    final Timestamp? createdAt = data['createdAt'];
    final dateStr = (createdAt != null)
        ? createdAt.toDate().toString().split('.').first
        : 'N/A';

    final invoiceUrl = data['invoiceUrl'] ?? '';
    final deliveryNoteUrl = data['deliveryNoteUrl'] ?? '';
    final invoiceNumber = data['invoiceNumber'] ?? 'N/A';

    // Other new fields
    final linkedStatus = data['linkedStatus'] ?? 'N/A';
    final installationDate = data['installationDate'] ?? 'N/A';
    final commissioningDate = data['commissioningDate'] ?? 'N/A';
    final functionalStatus = data['functionalStatus'] ?? 'N/A';
    final deliveryNoteNumber = data['deliveryNoteNumber'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Details'),
        backgroundColor: const Color(0xFF002244),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF004466), Color(0xFF002244)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Existing fields
                  _buildKeyValue("Equipment Type", type),
                  _buildKeyValue("Brand", brand),
                  _buildKeyValue("Model", model),
                  _buildKeyValue("Serial Number", serial),
                  _buildKeyValue("Created At", dateStr),
                  _buildKeyValue("Invoice Number", invoiceNumber),

                  const SizedBox(height: 16),

                  // New fields (excluding 'status')
                  _buildKeyValue("Linked Status", linkedStatus),
                  _buildKeyValue("Installation Date", installationDate),
                  _buildKeyValue("Commissioning Date", commissioningDate),
                  _buildKeyValue("Functional Status", functionalStatus),
                  _buildKeyValue("Delivery Note Number", deliveryNoteNumber),

                  const SizedBox(height: 16),

                  // Invoice
                  if (invoiceUrl.isNotEmpty) ...[
                    const Text(
                      'Invoice File',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _openFileUrl(invoiceUrl),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Open Invoice"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002244),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Delivery Note
                  if (deliveryNoteUrl.isNotEmpty) ...[
                    const Text(
                      'Delivery Note File',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _openFileUrl(deliveryNoteUrl),
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Open Delivery Note"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002244),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$key: ",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
