import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class UploadService {
  // Beispiel: printed = false, handwritten = true
  static Future<String> uploadImage(File imageFile, {required bool handwritten}) async {
    final uri = Uri.parse("http://141.22.50.234:8000/image_upload");    //Wifi Debugging + UniServer
    //final uri = Uri.parse("http://10.0.2.2:8000/image_upload");   //Emulator + HeimPC
    //final uri = Uri.parse("http://192.168.178.100:8000/image_upload");    //Wifi Debugging + Heim PC

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path))
      ..fields['handwritten'] = handwritten.toString()
      ..fields['text_type'] = handwritten ? 'handwritten' : 'printed';

    final res = await request.send();
    final resp = await http.Response.fromStream(res);

    // <-- wichtig für Debug:
    print('UPLOAD ${resp.statusCode}: ${resp.body}');

    if (resp.statusCode == 200) return resp.body;
    // Gib die Server-Fehlermeldung nach oben weiter:
    throw Exception('Upload failed: ${resp.statusCode} ${resp.body}');
  }

}

