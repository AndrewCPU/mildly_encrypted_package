import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:mildly_encrypted_package/src/utils/magic_nums.dart';
import 'package:mime/mime.dart';

class FileDownload {
  static Future<String> downloadFile(String url, String saveDirectory, {Function(double)? downloadProgress}) async {
    String dir = saveDirectory;
    if (!dir.endsWith(Platform.pathSeparator)) {
      dir += Platform.pathSeparator;
    }
    print(url);
    String fileName = url.split("/").last;
    Dio dio = Dio();

    File file = File('${dir}$fileName');
    await dio.download(url, file.path, onReceiveProgress: (re, to) {
      print(re / to.toDouble());
      if (downloadProgress != null) {
        downloadProgress(re / to.toDouble());
      }
    });
    return file.path;
  }

  static Future<String?> uploadFile(String path, {Function(double)? uploadProgress}) async {
    print("uploaded $path");
    String? mimeType = lookupMimeType(path.split(Platform.pathSeparator).last);
    mimeType ??= "application/octet-stream";
    Dio dio = Dio();
    print(path.substring(path.lastIndexOf(Platform.pathSeparator) + 1));
    var formData = FormData.fromMap({
      'files': [MultipartFile.fromFileSync(path)]
    });
    var response = await dio.post('https://${MagicNumber.SERVER_ADDRESS}:8080/upload/', data: formData, onSendProgress: (sent, total) {
      ELog.e((sent * 1.0 / total) * 100.0);
      if (uploadProgress != null) {
        uploadProgress(sent.toDouble() / total);
      }
    });
    if (response.statusCode == 200) {
      print("Upload complete!");
      return response.headers.value('uri')!;
    } else {
      return null;
    }
  }
}
