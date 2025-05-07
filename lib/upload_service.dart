import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class UploadService {
  static Future<String?> uploadImage(File imageFile, {required bool isHandwritten}) async {
    final uri = Uri.parse("http://141.22.50.234:80/upload");

    final request = http.MultipartRequest("POST", uri);
    request.fields['type'] = isHandwritten ? 'handwritten' : 'printed';
    request.files.add(
      await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: path.basename(imageFile.path),
      ),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.body; // oder ggf. JSON dekodieren
      } else {
        print("Upload fehlgeschlagen: ${response.statusCode}");
      }
    } catch (e) {
      print("Fehler beim Upload: $e");
    }

    return null;
  }
}