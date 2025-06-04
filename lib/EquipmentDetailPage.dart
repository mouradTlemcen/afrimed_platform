import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class EquipmentDetailPage extends StatelessWidget {
  final Map<String, dynamic> equipmentData;
  final String equipmentId;

  const EquipmentDetailPage({
    Key? key,
    required this.equipmentData,
    required this.equipmentId,
  }) : super(key: key);

  // Helper method to launch URLs (for downloading files)
  Future<void> _downloadFile(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw 'Could not launch $url';
    }
  }

  // Modified helper: sets mainAxisSize to min and uses Flexible instead of Expanded.
  Widget _buildKeyValue(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("$key: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Timestamp? ts = equipmentData['createdAt'];
    String dateStr =
    ts != null ? ts.toDate().toString().split('.').first : 'No date available';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipment Details"),
        backgroundColor: const Color(0xFF002244),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKeyValue('Brand', equipmentData['brand'] ?? 'N/A'),
                _buildKeyValue('Equipment Type', equipmentData['equipmentType'] ?? 'N/A'),
                _buildKeyValue('Model', equipmentData['model'] ?? 'N/A'),
                _buildKeyValue('Weight (kg)', equipmentData['weight'] ?? 'N/A'),
                _buildKeyValue('Dimension X (cm)', equipmentData['dimensionX'] ?? 'N/A'),
                _buildKeyValue('Dimension Y (cm)', equipmentData['dimensionY'] ?? 'N/A'),
                _buildKeyValue('Dimension Z (cm)', equipmentData['dimensionZ'] ?? 'N/A'),
                _buildKeyValue('Power Capacity (kW)', equipmentData['powerCapacity'] ?? 'N/A'),
                _buildKeyValue('Voltage (V)', equipmentData['voltage'] ?? 'N/A'),
                _buildKeyValue('Created At', dateStr),
                const SizedBox(height: 16),
                // Equipment Image (smaller)
                if (equipmentData['imageUrl'] != null &&
                    (equipmentData['imageUrl'] as String).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Equipment Image'),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Image.network(
                          equipmentData['imageUrl'],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                // Spare Parts
                if (equipmentData['spareParts'] != null &&
                    (equipmentData['spareParts'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Spare Parts'),
                      ...((equipmentData['spareParts'] as List).map((sp) {
                        final datasheetURL = sp['datasheetURL'] ?? '';
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text('${sp['name'] ?? ''} (${sp['brand'] ?? ''} / ${sp['model'] ?? ''})'),
                            subtitle: datasheetURL.isNotEmpty
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Datasheet: '),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await _downloadFile(datasheetURL);
                                  },
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text("Download", style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ],
                            )
                                : const Text('No datasheet'),
                          ),
                        );
                      })).toList(),
                    ],
                  ),
                const SizedBox(height: 16),
                // Service Kits
                if (equipmentData['serviceKits'] != null &&
                    (equipmentData['serviceKits'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Service Kits'),
                      ...((equipmentData['serviceKits'] as List).map((sk) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildKeyValue('Service Kit Name', sk['name'] ?? 'N/A'),
                                if (sk['globalDocument'] != null &&
                                    (sk['globalDocument'] as String).isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildKeyValue('Global Document', sk['globalDocument']),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          await _downloadFile(sk['globalDocument']);
                                        },
                                        icon: const Icon(Icons.download, size: 16),
                                        label: const Text("Download", style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (sk['items'] != null && (sk['items'] as List).isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionTitle('Items'),
                                      ...((sk['items'] as List).map((item) {
                                        return Card(
                                          elevation: 1,
                                          margin: const EdgeInsets.symmetric(vertical: 2),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildKeyValue('Name', item['name'] ?? 'N/A'),
                                                _buildKeyValue('Brand', item['brand'] ?? 'N/A'),
                                                _buildKeyValue('Model', item['model'] ?? 'N/A'),
                                                _buildKeyValue('Change Period (h)', item['changePeriod'] ?? 'N/A'),
                                                if (item['datasheetURL'] != null &&
                                                    (item['datasheetURL'] as String).isNotEmpty)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Text('Datasheet: '),
                                                      ElevatedButton.icon(
                                                        onPressed: () async {
                                                          await _downloadFile(item['datasheetURL']);
                                                        },
                                                        icon: const Icon(Icons.download, size: 16),
                                                        label: const Text("Download", style: TextStyle(fontSize: 12)),
                                                        style: ElevatedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      })).toList(),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      })).toList(),
                    ],
                  ),
                const SizedBox(height: 16),
                // Equipment Documents
                if (equipmentData['equipmentDocuments'] != null &&
                    (equipmentData['equipmentDocuments'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Equipment Documents'),
                      ...((equipmentData['equipmentDocuments'] as List).map((doc) {
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(doc['docType'] ?? 'N/A'),
                            subtitle: Text(doc['fileName'] ?? 'N/A'),
                            trailing: (doc['downloadURL'] != null &&
                                (doc['downloadURL'] as String).isNotEmpty)
                                ? ElevatedButton.icon(
                              onPressed: () async {
                                await _downloadFile(doc['downloadURL']);
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text("Download", style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            )
                                : null,
                          ),
                        );
                      })).toList(),
                    ],
                  ),
                const SizedBox(height: 16),
                _buildSectionTitle('Description'),
                Text(equipmentData['description'] ?? ''),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
