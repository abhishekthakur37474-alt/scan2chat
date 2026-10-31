import 'package:flutter/material.dart';
import '../models/contact_entry.dart';

enum EntryAction { view, edit, delete }

String formatEntryTime(DateTime t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '${t.day}/${t.month}/${t.year} · $h:$m';
}

class EntryTile extends StatelessWidget {
  final ContactEntry entry;
  final VoidCallback onTap; // Opens WhatsApp chat
  final void Function(EntryAction action) onAction;

  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = entry.name != null && entry.name!.isNotEmpty;
    final hasEmail = entry.email != null && entry.email!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF25D366),
          child: Icon(Icons.chat, color: Colors.white),
        ),
        // Number is always the highlight (title).
        title: Text(
          entry.display,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasName) Text(entry.name!),
            if (hasEmail) Text(entry.email!),
            Text(formatEntryTime(entry.scannedAt)),
          ],
        ),
        trailing: PopupMenuButton<EntryAction>(
          onSelected: onAction,
          itemBuilder: (context) => const [
            PopupMenuItem(value: EntryAction.view, child: Text('View')),
            PopupMenuItem(value: EntryAction.edit, child: Text('Edit')),
            PopupMenuItem(
              value: EntryAction.delete,
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}