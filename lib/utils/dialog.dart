import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../window/image.dart';

class ConfirmDialog extends StatelessWidget {
  final String imagePath;
  final Function onConfirm;

  const ConfirmDialog({super.key, required this.imagePath, required this.onConfirm});

  Future<void> _showConfirmDialog(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? alreadyConfirmed = prefs.getBool('confirmed');

    if (alreadyConfirmed == null || !alreadyConfirmed) {
      bool? confirmed = await showDialog<bool>(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmation'),
            content: const Text(
                'Pouvons-nous utiliser vos photos pour entraîner notre algorithme ?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Non'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Oui'),
              ),
            ],
          );
        },
      );

      if (confirmed != null && confirmed) {
        await prefs.setBool('confirmed', true);
        uploadImage(imagePath);
        onConfirm();
      } else {
        await prefs.setBool('confirmed', false);
        onConfirm();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showConfirmDialog(context);
    });

    return Container();
  }

}


