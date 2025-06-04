import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewPartnerPage extends StatefulWidget {
  final String partnerId;

  const ViewPartnerPage({Key? key, required this.partnerId}) : super(key: key);

  @override
  _ViewPartnerPageState createState() => _ViewPartnerPageState();
}

class _ViewPartnerPageState extends State<ViewPartnerPage> {
  Map<String, dynamic>? partnerData;
  List<dynamic>? personsInOrganization;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPartnerData();
  }

  void fetchPartnerData() async {
    try {
      final partnerDoc = await FirebaseFirestore.instance
          .collection('partners')
          .doc(widget.partnerId)
          .get();

      if (partnerDoc.exists) {
        setState(() {
          partnerData = partnerDoc.data();
          personsInOrganization = partnerData?['persons'] as List<dynamic>?;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partner not found.')),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching partner data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Partner'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : partnerData == null
          ? const Center(
        child: Text(
          'No data available for this partner.',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Logo and Name
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: partnerData?['logoUrl'] != null
                          ? NetworkImage(partnerData!['logoUrl'])
                          : null,
                      child: partnerData?['logoUrl'] == null
                          ? const Icon(
                        Icons.business,
                        size: 50,
                        color: Colors.grey,
                      )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      partnerData?['name'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Partnership Information
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partnership Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    InfoRow(
                        label: 'Partnership Type',
                        value: partnerData?['partnershipType'] ?? 'N/A'),
                    InfoRow(
                        label: 'Country',
                        value: partnerData?['country'] ?? 'N/A'),
                    InfoRow(
                        label: 'Address',
                        value: partnerData?['address'] ?? 'N/A'),
                    if (partnerData?['comment'] != null &&
                        (partnerData?['comment'] as String).isNotEmpty)
                      InfoRow(
                          label: 'Comment',
                          value: partnerData?['comment'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contact Information
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    InfoRow(
                        label: 'Email',
                        value: partnerData?['contactDetails']?['email'] ?? 'N/A'),
                    InfoRow(
                        label: 'Phone',
                        value: partnerData?['contactDetails']?['phone'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Supplier Details (if applicable)
            if (partnerData?['partnershipType'] == 'Supplier' &&
                partnerData?['supplierDetails'] != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supplier Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      InfoRow(
                          label: 'Service Name',
                          value: partnerData?['supplierDetails']?['serviceName'] ?? 'N/A'),
                      InfoRow(
                          label: 'Brand Name',
                          value: partnerData?['supplierDetails']?['brandName'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Persons in Organization
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Persons in Organization',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    if (personsInOrganization != null &&
                        personsInOrganization!.isNotEmpty)
                      ...personsInOrganization!.asMap().entries.map((entry) {
                        final person = entry.value as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person['name'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Position: ${person['position'] ?? 'N/A'}'),
                              Text('Email: ${person['email'] ?? 'N/A'}'),
                              Text('Phone: ${person['phone'] ?? 'N/A'}'),
                              const Divider(),
                            ],
                          ),
                        );
                      }).toList()
                    else
                      const Text(
                        'No persons found in the organization.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
