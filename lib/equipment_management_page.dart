import 'package:flutter/material.dart';
import 'EquipmentListPage.dart';
import 'AcquiredEquipmentListPage.dart';

class EquipmentManagementPage extends StatelessWidget {
  const EquipmentManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // You can optionally get the screen size here too:
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Equipment Management"),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Decide how many columns based on total width
            int crossAxisCount;
            if (constraints.maxWidth >= 900) {
              crossAxisCount = 4; // bigger screens
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 3; // medium screens
            } else {
              crossAxisCount = 2; // small screens
            }

            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // childAspectRatio < 1 => taller cards, > 1 => wider cards
              // Adjust to your preference
              childAspectRatio: 0.9,
              children: [
                // Card for "Equipment List"
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EquipmentListPage(),
                      ),
                    );
                  },
                  child: _buildCard(
                    icon: Icons.list,
                    label: "Equipment List",
                  ),
                ),

                // Card for "Acquired Equipment"
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AcquiredEquipmentListPage(),
                      ),
                    );
                  },
                  child: _buildCard(
                    icon: Icons.shopping_cart_outlined,
                    label: "Acquired Equipment",
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard({required IconData icon, required String label}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
