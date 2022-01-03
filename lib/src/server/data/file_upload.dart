import 'dart:convert';
import 'dart:io';

import 'package:mildly_encrypted_package/src/logging/ELog.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_multipart/multipart.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:uuid/uuid.dart';

class FileUploadServer {
  String webAddress = "https://dialapp.chat/";
  // String webAddress = '192.168.1.5';
  // String imageDirectory = "./encrypted_images/";

  FileUploadServer() {
    () async {
      var app = Router();
      app.post('/upload/', _handler);
      // app.mount("/encrypted_images/",
      //     ShelfVirtualDirectory(imageDirectory, listDirectory: true).handler);
      var server = await shelf_io.serve(app, '0.0.0.0', 8080);
      server.defaultResponseHeaders.add('Access-Control-Allow-Origin', '*');
    }.call();
  }
  Future<Response> _handler(Request request) async {
    if (!request.isMultipart) {
      return Response.ok('Not a multipart request');
    } else if (request.isMultipartForm) {
      // final description = StringBuffer('Parsed form multipart request\n');
      List<int> data = [];
      var fileName = "";
      await for (final formData in request.multipartFormData) {
        var monkey = await formData.part.toList();
        for (var monk in monkey) {
          data.addAll(monk);
        }
        fileName = formData.filename!;
      }
      String newName = Uuid().v4() + "-" + fileName;
      ELog.i("File Upload: " + newName);
      await File("/var/www/html/encrypted_images/" + newName).writeAsBytes(data);

      return Response.ok(jsonEncode({'upload': 'ok'}), headers: {"uri": webAddress + "/encrypted_images/" + newName});
    } else {
      final description = StringBuffer('Regular multipart request\n');

      await for (final part in request.parts) {
        description.writeln('new part');

        part.headers.forEach((key, value) => description.writeln('Header $key=$value'));
        final content = await part.readString();
        description.writeln('content: $content');

        description.writeln('end of part');
      }

      return Response.ok(description.toString());
    }
  }
}
