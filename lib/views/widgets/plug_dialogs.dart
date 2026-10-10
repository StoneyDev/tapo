import 'package:flutter/material.dart';
import 'package:tapo/core/validators.dart';

/// Asks for a new IP address; returns null when cancelled or unchanged.
Future<String?> showEditIpDialog(BuildContext context, String currentIp) async {
  final controller = TextEditingController(text: currentIp);
  final formKey = GlobalKey<FormState>();
  final newIp = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Modifier l'adresse IP"),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Adresse IP',
            hintText: '192.168.1.100',
          ),
          validator: (value) {
            final ip = value?.trim() ?? '';
            if (ip.isEmpty) return 'Adresse IP requise';
            if (!isValidIpv4(ip)) return 'Format IP invalide';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, controller.text.trim());
            }
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  return newIp == currentIp ? null : newIp;
}

/// Asks to confirm removing the plug named [nickname].
Future<bool> confirmPlugRemoval(BuildContext context, String nickname) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Supprimer?'),
          content: Text('Supprimer $nickname?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ) ??
      false;
}
