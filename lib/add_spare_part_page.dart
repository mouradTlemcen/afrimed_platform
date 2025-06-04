import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddSparePartPage extends StatefulWidget {
  final String equipmentId;

  const AddSparePartPage({Key? key, required this.equipmentId}) : super(key: key);

  @override
  _AddSparePartPageState createState() => _AddSparePartPageState();
}

class _AddSparePartPageState extends State<AddSparePartPage> {
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController serialNumberController = TextEditingController();
  DateTime? expirationDate;
  String selectedSparePartType = "Filter"; // Default value

  void _pickExpirationDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        expirationDate = picked;
      });
    }
  }

  void _addSparePart() async {
    if (brandController.text.isEmpty || modelController.text.isEmpty || serialNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields!')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('equipment')
        .doc(widget.equipmentId)
        .collection('spareParts')
        .add({
      'type': selectedSparePartType,
      'brand': brandController.text.trim(),
      'model': modelController.text.trim(),
      'serialNumber': serialNumberController.text.trim(),
      'expirationDate': expirationDate != null
          ? expirationDate!.toIso8601String().split('T')[0]
          : 'Not Concerned',
      'addedDate': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Spare Part added successfully!')),
    );

    Navigator.pop(context);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Spare Part'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      "Adding Spare Part for Equipment ID: ${widget.equipmentId}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: selectedSparePartType,
                      onChanged: (newValue) {
                        setState(() {
                          selectedSparePartType = newValue!;
                        });
                      },
                      items: [
                        'Filter',
                        'Oil Separator',
                        'Valve',
                        'Sensor',
                        'Dryer Cartridge',
                        'Gasket',
                        'Air Regulator',
                        'Pump',
                        'Cylinder',
                        'Motor',
                        'Electrical Board'
                      ].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      decoration: const InputDecoration(labelText: 'Spare Part Type'),
                    ),

                    const SizedBox(height: 16),
                    _buildTextField(controller: brandController, label: 'Brand', icon: Icons.business),
                    _buildTextField(controller: modelController, label: 'Model', icon: Icons.build),
                    _buildTextField(controller: serialNumberController, label: 'Serial Number', icon: Icons.confirmation_number),

                    const SizedBox(height: 16),
                    expirationDate != null
                        ? Text(
                      'Expiration Date: ${expirationDate!.toLocal()}'.split(' ')[0],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    )
                        : const Text('Expiration Date: Not Concerned', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ElevatedButton(
                      onPressed: _pickExpirationDate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8D1B3D),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Pick Expiration Date', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _addSparePart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0073E6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Add Spare Part', style: TextStyle(fontSize: 16, color: Colors.white)),
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
