import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:intl/intl.dart';

class EditFormPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? imagePath;
  const EditFormPage({super.key, required this.data, this.imagePath});

  @override
  State<EditFormPage> createState() => _EditFormPageState();
}

class _EditFormPageState extends State<EditFormPage> {
  final Map<String, TextEditingController> controllers = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  List<String> _availableDates = [];
  List<String> _availableTimes = [];
  int duration = 0;
  bool _isAllDay = false;



  @override
  void initState() {
    super.initState();

    //Sinnvolle Daten?
    final criticalKeys = ['Titel', 'Datum', 'Startzeit', 'Location'];
    final allEmpty = criticalKeys.every((key) =>
    widget.data[key] == null || widget.data[key].toString().trim().isEmpty);

    if (allEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Auf dem Bild konnten leider keine Daten erkannt werden.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      });
    }

    // Textfelder: Titel, Beschreibung, Location
    _titleController.text = widget.data['Titel'] ?? '';
    _descriptionController.text = widget.data['Beschreibung'] ?? '';
    _locationController.text = widget.data['Location'] ?? '';

    // Dauer auslesen (optional)
    duration = widget.data['duration'] ?? 0;

    // Datumsliste vorbereiten
    final List<String> dateList = _extractList(widget.data['Datum']);
    final List<String> sortedDates = _sortDates(dateList);

    String startDate = sortedDates.isNotEmpty ? sortedDates.first : DateFormat('dd.MM.yyyy').format(DateTime.now());
    String endDate = sortedDates.length >= 2 ? sortedDates.last : startDate;

    // Zeiten vorbereiten
    final List<String> startTimes = _extractList(widget.data['Startzeit']);

    // Diese Variablen VORHER definieren!
    String startTime = '';
    String endTime = '';
    List<String> sortedStartTimes = [];

    // Sonderfall: enthält einen Ganztägig-Wert?
    if (startTimes.any((t) => t.toLowerCase().contains('ganztägig'))) {
      _isAllDay = true;
      _startTimeController.text = '';
      _endTimeController.text = '';
    } else {
      sortedStartTimes = _sortTimes(startTimes);
      startTime = sortedStartTimes.isNotEmpty ? sortedStartTimes.first : '';
      endTime = '';

      if (sortedStartTimes.length >= 2) {
        endTime = sortedStartTimes.last;
      } else if (widget.data.containsKey('Endzeit')) {
        final List<String> endTimes = _extractList(widget.data['Endzeit']);
        final List<String> sortedEndTimes = _sortTimes(endTimes);
        endTime = sortedEndTimes.isNotEmpty ? sortedEndTimes.first : '';
      } else if (startTime.isNotEmpty) {
        endTime = _calculateEndTime(startTime, duration > 0 ? duration : 2);
      }

      _startTimeController.text = startTime;
      _endTimeController.text = endTime;

      _availableTimes = sortedStartTimes;
    }

// Safety fallback
    if (_availableTimes.isEmpty) _availableTimes.add('');


    // Controller setzen
    _dateController.text = startDate;
    _endDateController.text = endDate;
    _startTimeController.text = startTime;
    _endTimeController.text = endTime;

    // Listen für Dropdowns speichern
    _availableDates = sortedDates;
    _availableTimes = sortedStartTimes;

    // Safety fallback
    if (_availableDates.isEmpty) _availableDates.add('');
    if (_availableTimes.isEmpty) _availableTimes.add('');

    // Map füllen
    controllers['Titel'] = _titleController;
    controllers['Datum'] = _dateController;
    controllers['Enddatum'] = _endDateController;
    controllers['Startzeit'] = _startTimeController;
    controllers['Endzeit'] = _endTimeController;
    controllers['Beschreibung'] = _descriptionController;
    controllers['Location'] = _locationController;
  }

  List<String> _extractList(dynamic value) {
    if (value == null) return [];
    if (value is List) return List<String>.from(value);
    return [value.toString()];
  }

  List<String> _sortDates(List<String> dates) {
    final format = DateFormat('dd.MM.yyyy');
    return List<String>.from(dates)
      ..sort((a, b) => format.parse(a).compareTo(format.parse(b)));
  }

  List<String> _sortTimes(List<String> times) {
    final validTimes = times.where((t) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(t)).toList();

    validTimes.sort((a, b) =>
        DateFormat("HH:mm").parse(a).compareTo(DateFormat("HH:mm").parse(b)));

    return validTimes;
  }

  String _calculateEndTime(String startTime, int durationHours) {
    final format = DateFormat('HH:mm');
    final start = format.parse(startTime);
    final end = start.add(Duration(hours: durationHours));
    return format.format(end);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return controllers['Titel']?.text.isNotEmpty == true &&
        controllers['Datum']?.text.isNotEmpty == true &&
        controllers['Startzeit']?.text.isNotEmpty == true;
  }

  Future<void> _handleSave({required bool share}) async {

    // Endzeit berechnen, falls leer
    if (_endTimeController.text.trim().isEmpty && !_isAllDay) {
      print('Startzeit: ${_startTimeController.text}');
      _endTimeController.text = _calculateEndzeit(_startTimeController.text.trim());
    }

    if (!_isFormValid) {
      final missingFields = [];
      if (_titleController.text.trim().isEmpty) missingFields.add('Titel');
      if (_dateController.text.trim().isEmpty) missingFields.add('Datum');
      if (!_isAllDay && _startTimeController.text.isEmpty) missingFields.add('Startzeit');

      final message =
          'Die Felder ${missingFields.join(', ')} dürfen nicht leer sein.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    final titel = _titleController.text.trim();
    final datum = _dateController.text.trim();
    final enddatum = _endDateController.text.trim();
    final startzeit = _startTimeController.text.trim();
    final endzeit = _endTimeController.text.trim();
    final beschreibung = _descriptionController.text.trim();
    final ort = _locationController.text.trim();

    final start = DateTime.parse("${_formatDateForParsing(datum)}T${_isAllDay ? '00:00' : _formatTimeForParsing(startzeit)}:00");
    DateTime end;

    if (enddatum.isEmpty) {
      // Kein Enddatum: gleiche wie Start, plus Duration oder +2h
      if (_isAllDay) {
        end = start;
      } else if (duration > 0) {
        end = start.add(Duration(minutes: duration));
      } else {
        end = start.add(const Duration(hours: 2));
      }
    } else {
      // Normale Verarbeitung mit Enddatum
      end = DateTime.parse("${_formatDateForParsing(enddatum)}T${_isAllDay ? '00:00' : _formatTimeForParsing(endzeit)}:01");
    }

    if (share) {
      await _exportAsCalendarEvent(titel, start, end, beschreibung, ort, share: true);
    } else {
      await _exportAsCalendarEvent(titel, start, end, beschreibung, ort, share: false);
    }
  }

  String _formatDateForParsing(String input) {
    // "12.04.2025" → "2025-04-12"
    final parts = input.split('.');
    if (parts.length != 3) return input; // fallback
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
            _availableDates.length > 1
                ? _buildTextFieldWithDropdown(label:'Datum',options: _availableDates,controller: _dateController)
                : _buildTextField('Datum', _dateController),
            _availableDates.length > 1
                ? _buildTextFieldWithDropdown(label:'Enddatum',options: _availableDates,controller: _endDateController)
                : _buildTextField('Enddatum', _endDateController),
            SwitchListTile(
              title: const Text("Ganztägig"),
              value: _isAllDay,
              onChanged: (value) {
                setState(() {
                  _isAllDay = value;
                });
              },
            ),

            _availableTimes.length > 1
                ? _buildTextFieldWithDropdown(label: 'Startzeit',options: _availableTimes,controller: _startTimeController, enabled: !_isAllDay,)
                : _buildTextField('Startzeit', _startTimeController),
            _availableTimes.length > 1
                ? _buildTextFieldWithDropdown(label:'Endzeit',options: _availableTimes,controller: _endTimeController, enabled: !_isAllDay,)
                : _buildTextField('Endzeit', _endTimeController),
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
          enabled: !(label.contains('zeit') && _isAllDay), // <— hier eingefügt
        ),
      ),
    );
  }


  Widget _buildTextFieldWithDropdown({
    required String label,
    required List<String> options,
    required TextEditingController controller,
    bool enabled = true,
  }) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        final LayerLink _layerLink = LayerLink();
        OverlayEntry? _overlayEntry;

        void _showDropdown() {
          _overlayEntry = OverlayEntry(
            builder: (context) => Positioned(
              width: MediaQuery.of(context).size.width - 64, // padding left+right
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 56),
                child: Material(
                  elevation: 4.0,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: options.map((option) {
                      return ListTile(
                        title: Text(option),
                        onTap: () {
                          controller.text = option;
                          _overlayEntry?.remove();
                          _overlayEntry = null;
                          setInnerState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          );

          Overlay.of(context).insert(_overlayEntry!);
        }

        void _hideDropdown() {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0), // mehr Abstand
          child: CompositedTransformTarget(
            link: _layerLink,
            child: TextFormField(
              enabled: enabled,
              controller: controller,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  onPressed: () {
                    if (_overlayEntry == null) {
                      _showDropdown();
                    } else {
                      _hideDropdown();
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCalendarWithEvent({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
    required bool isAllDay,
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
        'allDay': isAllDay,
      },
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    await intent.launch();
  }

  String _generateIcsEntry({
    required String titel,
    required DateTime start,
    required DateTime end,
    required String beschreibung,
    required String ort,
    required bool isAllDay,
  }) {
    final startStr = isAllDay
        ? start.toIso8601String().split('T').first.replaceAll('-', '')
        : _formatDateTimeICS(start);
    final endStr = isAllDay
        ? end.toIso8601String().split('T').first.replaceAll('-', '')
        : _formatDateTimeICS(end);

    final dtStartPrefix = isAllDay ? 'DTSTART;VALUE=DATE:' : 'DTSTART:';
    final dtEndPrefix = isAllDay ? 'DTEND;VALUE=DATE:' : 'DTEND:';

    return '''
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//DeineApp//KalenderExport//DE
BEGIN:VEVENT
SUMMARY:$titel
${dtStartPrefix}$startStr
${dtEndPrefix}$endStr
DESCRIPTION:$beschreibung
LOCATION:$ort
END:VEVENT
END:VCALENDAR
''';
  }

  Future<void> _exportAsCalendarEvent(
      String titel,
      DateTime start,
      DateTime end,
      String beschreibung,
      String ort,
      {required bool share}
      ) async {
    final icsContent = _generateIcsEntry(
      titel: titel,
      start: start,
      end: end,
      beschreibung: beschreibung,
      ort: ort,
      isAllDay: _isAllDay,
    );

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
        isAllDay: _isAllDay,
      );
    }
  }
}