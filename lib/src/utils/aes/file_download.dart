import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';
import 'package:mime/mime.dart';

class FileDownload {
  static Future<String> downloadFile(String url, String chatID, String saveDirectory) async {
    http.Client client = new http.Client();
    var req = await client.get(Uri.parse(url));
    var bytes = req.bodyBytes;
    String dir = saveDirectory;
    String fileName = url.split("/").last;
    Directory directory = Directory("$dir/$chatID/");
    if (!(await directory.exists())) {
      await directory.create(recursive: true);
    }
    File file = File('$dir/$chatID/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static Future<String?> uploadFile(String path) async {
    String? mimeType = lookupMimeType(path.split("/").last);
    mimeType ??= "application/octet-stream";
    var request = http.MultipartRequest("POST", Uri.parse("http://${MagicNumber.SERVER_ADDRESS}:8080/upload/"));
    request.files.add(await http.MultipartFile.fromPath('package', path, contentType: MediaType.parse(mimeType)));
    http.StreamedResponse response = await request.send();
    if (response.statusCode == 200) {
      print("Uploaded!");
      return response.headers['uri']!;
    } else {
      return null;
    }
  }
}
