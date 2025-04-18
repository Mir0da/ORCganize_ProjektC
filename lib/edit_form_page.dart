import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class EditFormPage extends StatefulWidget {
  final Map<String, String> data;
  final String? imagePath;
  const EditFormPage({super.key, required this.data, this.imagePath});

  @override
  State<EditFormPage> createState() => _EditFormPageState();
}

class _EditFormPageState extends State<EditFormPage> {
  final Map<String, TextEditingController> controllers = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _titleController.text = widget.data['Titel'] ?? '';
    _dateController.text = widget.data['Datum'] ?? '';
    _startTimeController.text = widget.data['Startzeit'] ?? '';
    _endTimeController.text = widget.data['Endzeit'] ?? '';
    _descriptionController.text = widget.data['Beschreibung'] ?? '';
    _locationController.text = widget.data['Location'] ?? '';

    controllers['Titel'] = _titleController;
    controllers['Datum'] = _dateController;
    controllers['Startzeit'] = _startTimeController;
    controllers['Endzeit'] = _endTimeController;
    controllers['Beschreibung'] = _descriptionController;
    controllers['Location'] = _locationController;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return controllers['Titel']?.text.isNotEmpty == true &&
        controllers['Datum']?.text.isNotEmpty == true &&
        controllers['Startzeit']?.text.isNotEmpty == true;
  }

  Future<void> _handleSave({required bool share}) async {

    // Endzeit berechnen, falls leer
    if (_endTimeController.text.trim().isEmpty) {
      _endTimeController.text = _calculateEndzeit(_startTimeController.text.trim());
    }

    if (!_isFormValid) {
      final missingFields = [];
      if (_titleController.text.trim().isEmpty) missingFields.add('Titel');
      if (_dateController.text.trim().isEmpty) missingFields.add('Datum');
      if (_startTimeController.text.trim().isEmpty) missingFields.add('Startzeit');

      final message =
          'Die Felder ${missingFields.join(', ')} dürfen nicht leer sein.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final titel = _titleController.text.trim();
    final datum = _dateController.text.trim();
    final startzeit = _startTimeController.text.trim();
    final endzeit = _endTimeController.text.trim();
    final beschreibung = _descriptionController.text.trim();
    final ort = _locationController.text.trim();

    final start = DateTime.parse("${_formatDateForParsing(datum)}T${_formatTimeForParsing(startzeit)}:00");
    final end = DateTime.parse("${_formatDateForParsing(datum)}T${_formatTimeForParsing(endzeit)}:00");

    if (share) {
      await _exportAsCalendarEvent(titel, start, end, beschreibung, ort, share: true);
    } else {
      await _exportAsCalendarEvent(titel, start, end, beschreibung, ort, share: false);
    }
  }

  String _formatDateForParsing(String input) {
    // "12.04.2025" → "2025-04-12"
    final parts = input.split('.');
    return "${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}";
  }

  String _formatTimeForParsing(String input) {
    // "20:00"
    return input.padLeft(5, '0');
  }

  String _formatDateTimeICS(DateTime dt) {
    // → "20250412T200000"
    return "${dt.year.toString().padLeft(4, '0')}"
        "${dt.month.toString().padLeft(2, '0')}"
        "${dt.day.toString().padLeft(2, '0')}T"
        "${dt.hour.toString().padLeft(2, '0')}"
        "${dt.minute.toString().padLeft(2, '0')}"
        "00";
  }

  String _calculateEndzeit(String startzeit) {
    try {
      final timeParts = startzeit.split(':');
      final start = DateTime(0, 1, 1, int.parse(timeParts[0]), int.parse(timeParts[1]));
      final end = start.add(const Duration(hours: 2));
      final formatted = "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";
      return formatted;
    } catch (e) {
      return startzeit; // Fallback, falls Zeit nicht korrekt ist
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daten bearbeiten'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,), // AppBar-Hintergrundfarbe aus dem Theme),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (widget.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20.0),
                  height: 200.0,
                  child: ClipRect(
                    child: PhotoView(
                      imageProvider: FileImage(File(widget.imagePath!)),
                      maxScale: PhotoViewComputedScale.covered * 2.0,
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      initialScale: PhotoViewComputedScale.contained,
                    ),
                  ),
                ),
              ),
            _buildTextField('Titel', _titleController),
            _buildTextField('Datum', _dateController),
            _buildTextField('Startzeit', _startTimeController),
            _buildTextField('Endzeit', _endTimeController),
            _buildTextField('Beschreibung', _descriptionController),
            _buildTextField('Location', _locationController),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _handleSave(share: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFormValid ? Colors.teal : Colors.grey,
                foregroundColor: Colors.white, // Textfarbe anpassen
              ),
              child: const Text("Im Kalender öffnen"),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () => _handleSave(share: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white, // Textfarbe anpassen
              ),
              child: const Text("ICS-Datei teilen"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        onChanged: (_) => setState(() {}), // aktualisiert Button-Zustand
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }


  Future<void> _openCalendarWithEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.INSERT',
      type: 'vnd.android.cursor.item/event',
      arguments: <String, dynamic>{
        'title': title,
        'description': description,
        'eventLocation': location,
        'beginTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
      },
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    await intent.launch();
  }

  Future<void> _exportAsCalendarEvent(
      String titel,
      DateTime start,
      DateTime end,
      String beschreibung,
      String ort,
      {required bool share}
      ) async {
    final icsContent = '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//DeineApp//KalenderExport//DE
BEGIN:VEVENT
SUMMARY:$titel
DTSTART:${_formatDateTimeICS(start)}
DTEND:${_formatDateTimeICS(end)}
DESCRIPTION:$beschreibung
LOCATION:$ort
END:VEVENT
END:VCALENDAR
''';

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/event.ics';
    final file = File(filePath);
    await file.writeAsString(icsContent);

    //Datei speichern
    //await _exportIcsFileToDownloads(icsContent);

    // Datei teilen
    if (share) {
      await Share.shareXFiles([XFile(filePath)], text: 'Kalendereintrag für $titel');
    } else {
      await _openCalendarWithEvent(
        title: titel,
        description: beschreibung,
        location: ort,
        start: start,
        end: end,
      );
    }
  }
}