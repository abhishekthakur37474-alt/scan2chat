import 'package:flutter/material.dart';
import '../models/contact_entry.dart';

class EditResult {
  final String number; // 10 digits
  final String? name;
  final String? email;

  const EditResult({required this.number, this.name, this.email});
}

/// Returns the edited values, or null if cancelled.
Future<EditResult?> showEditDialog(BuildContext context, ContactEntry entry) {
  final nameController = TextEditingController(text: entry.name ?? '');
  final numberController = TextEditingController(
    text: entry.display.replaceAll('+91', '').trim(),
  );
  final emailController = TextEditingController(text: entry.email ?? '');
  final formKey = GlobalKey<FormState>();

  return showDialog<EditResult>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Contact'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
              TextFormField(
                controller: numberController,
                decoration: const InputDecoration(labelText: 'Number', prefixText: '+91 '),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) {
                  final digits = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  if (digits.length != 10 || !RegExp(r'^[6-9]').hasMatch(digits)) {
                    return 'Enter a valid 10-digit Indian number';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              final digits = numberController.text.replaceAll(RegExp(r'[^\d]'), '');
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              Navigator.pop(
                context,
                EditResult(
                  number: digits,
                  name: name.isEmpty ? null : name,
                  email: email.isEmpty ? null : email.toLowerCase(),
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}