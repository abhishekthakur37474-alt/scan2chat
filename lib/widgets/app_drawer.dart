import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  final int totalScanned;
  final VoidCallback onClearHistory;

  const AppDrawer({
    super.key,
    required this.totalScanned,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF25D366)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.contact_page, color: Color(0xFF25D366), size: 32),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Scan2Chat',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('$totalScanned contacts scanned',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear history'),
            onTap: () {
              Navigator.pop(context);
              onClearHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}