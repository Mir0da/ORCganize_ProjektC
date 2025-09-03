import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:projekt_c/upload_service.dart';
import 'theme_manager.dart';
import 'dart:async';

class SettingsPage extends StatefulWidget {
  final ValueNotifier<ThemeMode> themeNotifier;
  const SettingsPage({super.key, required this.themeNotifier});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  String _theme = 'Dark'; // Options: 'Light', 'Dark', 'System'
  String _status = 'Noch nicht getestet';

  @override
  void initState() {
    super.initState();
    _loadCurrentTheme();
  }

  // Lädt das aktuell gespeicherte Theme
  Future<void> _loadCurrentTheme() async {
    final currentTheme = await ThemeManager.loadTheme();
    setState(() {
      _theme = currentTheme;
    });
  }

  // Speichern des Themes in SharedPreferences
  Future<void> _saveTheme(String theme) async {
    await ThemeManager.saveTheme(theme); // Speichert das ausgewählte Theme
    widget.themeNotifier.value = ThemeManager.getThemeMode(theme); // Aktualisiere das Theme
  }

  Future<void> testConnection() async {
    setState(() {
      _status = 'Verbindung wird getestet...';
    });


    try {
//      final response = await http.get(Uri.parse('http://141.22.50.234:80/ping')).timeout(const Duration(seconds: 5)); //UniServer
//      final response = await http.get(Uri.parse('http://10.0.2.2:8000/ping')).timeout(const Duration(seconds: 5));      //Emulator + Heim PC
      final response = await http.get(Uri.parse('http://192.168.178.100:8000/ping')).timeout(const Duration(seconds: 5));      //Test auf Real Gerät, server auf HeimPC


      if (response.statusCode == 200) {
        setState(() {
          _status = '✅ Verbindung erfolgreich! Server IP: 192.168.178.100';
        });
      } else {
        setState(() {
          _status = '⚠️ Server antwortete mit Status: ${response.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        _status = '⏰ Zeitüberschreitung – Server nicht erreichbar.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Verbindung fehlgeschlagen: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Server Connection Test (TODO)
          ListTile(
            title: const Text('Server Verbindung testen'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Überprüfe ob die App eine Verbindung zum Server herstellen kann'),
                const SizedBox(height: 4),
                Text(
                  _status,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            onTap: testConnection,
          ),

          // 2. Theme Selection
          ListTile(
            title: const Text('Thema auswählen'),
            subtitle: Text('Aktuelles Thema: $_theme'),
            onTap: () {
              _showThemeDialog();
            },
          ),

          // 3. Send Feedback & Bug Reports
          ListTile(
            title: const Text('Feedback senden & Fehler melden'),
            subtitle: const Text('Melde Fehler oder schlage Verbesserungen vor.'),
            onTap: () {
              _showFeedbackDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Thema auswählen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('Hell'),
                value: 'Light',
                groupValue: _theme,
                onChanged: (String? value) {
                  Navigator.pop(context, value);
                },
              ),
              RadioListTile<String>(
                title: const Text('Dunkel'),
                value: 'Dark',
                groupValue: _theme,
                onChanged: (String? value) {
                  Navigator.pop(context, value);
                },
              ),
              RadioListTile<String>(
                title: const Text('System'),
                value: 'System',
                groupValue: _theme,
                onChanged: (String? value) {
                  Navigator.pop(context, value);
                },
              ),
            ],
          ),
        );
      },
    ).then((String? value) {
      if (value != null) {
        setState(() {
          _theme = value;
          _saveTheme(value); // Speichern des Themes in SharedPreferences
        });
      }
    });
  }

  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Feedback senden'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feedbackController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Gib uns hier dein Feedback oder melde einen Fehler...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  hintText: 'Deine email (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Senden'),
              onPressed: () {
                sendFeedbackToGoogleForm(
                    feedbackController.text,
                    emailController.text,
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vielen Dank für dein Feedback!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> sendFeedbackToGoogleForm(String message, String email) async {
    final uri = Uri.parse(
        'https://docs.google.com/forms/u/0/d/e/1FAIpQLScE9gPmyW1UZ8J9oxrixhwooB0_TGfaramdL5gqWSqt_zkjFw/formResponse');

    final response = await http.post(
      uri,
      body: {
        'entry.2091146587': message, // Ersetze mit dem echten Entry-Code
        'entry.996110799': email, // Optionales Feld
      },
    );

    if (response.statusCode == 200 || response.statusCode == 302) {
      print('Feedback erfolgreich gesendet!');
    } else {
      print('Fehler beim Senden: ${response.statusCode}');
    }
  }
}