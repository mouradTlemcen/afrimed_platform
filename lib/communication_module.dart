// File: communication_module.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunicationModule extends StatelessWidget {
  // Sample list of WhatsApp groups.
  final List<Map<String, String>> groups = [
    {
      'name': 'General Announcements',
      'url': 'https://chat.whatsapp.com/your_general_group_invite_code'
    },
    {
      'name': 'Project Updates',
      'url': 'https://chat.whatsapp.com/your_project_updates_invite_code'
    },
    {
      'name': 'Technical Support',
      'url': 'https://chat.whatsapp.com/your_tech_support_invite_code'
    },
  ];

  // Function to launch a URL.
  Future<void> _launchGroup(String groupUrl) async {
    final Uri url = Uri.parse(groupUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $groupUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Communication Module"),
        backgroundColor: Color(0xFF003366),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: groups.length,
        separatorBuilder: (context, index) => Divider(),
        itemBuilder: (context, index) {
          final group = groups[index];
          return ListTile(
            leading: Icon(Icons.chat, color: Colors.green),
            title: Text(group['name']!, style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () => _launchGroup(group['url']!),
          );
        },
      ),
    );
  }
}
