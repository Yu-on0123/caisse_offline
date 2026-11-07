import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';

/// Ouvre l'espace web dans le navigateur de l'appareil. Si l'ouverture échoue,
/// l'adresse est affichée pour que l'utilisateur puisse la saisir lui-même.
Future<void> openWebSpace(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(AppConfig.webUrl);

  var opened = false;
  if (uri != null && uri.hasScheme) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }

  if (!opened) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          "Impossible d'ouvrir le lien automatiquement. "
          'Ouvrez cette adresse dans votre navigateur : ${AppConfig.webUrl}',
        ),
      ),
    );
  }
}
