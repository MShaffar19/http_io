// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import "dart:typed_data";

import "package:http_io/http_io.dart";
import "package:test/test.dart";

Future<Null> testClientRequest(Future handler(request)) {
  Completer<Null> completer = new Completer();
  HttpServer.bind("127.0.0.1", 0).then((server) {
    server.listen((request) {
      request.drain().then((_) => request.response.close()).catchError((_) {});
    });

    var client = new HttpClient();
    client
        .get("127.0.0.1", server.port, "/")
        .then((request) {
          return handler(request);
        })
        .then((response) => response.drain())
        .catchError((_) {})
        .whenComplete(() {
          client.close();
          server.close();
          completer.complete(null);
        });
  });
  return completer.future;
}

Future<Null> testResponseDone() async {
  await testClientRequest((request) {
    request.close().then((res1) {
      request.done.then((res2) {
        expect(res1, equals(res2));
      });
    });
    return request.done;
  });
}

Future<Null> testBadResponseAdd() async {
  await testClientRequest((request) {
    request.contentLength = 0;
    request.add([0]);
    request.close();
    request.done.catchError((error) {}, test: (e) => e is HttpException);
    return request.done;
  });

  await testClientRequest((request) {
    request.contentLength = 5;
    request.add([0, 0, 0]);
    request.add([0, 0, 0]);
    request.close();
    request.done.catchError((error) {}, test: (e) => e is HttpException);
    return request.done;
  });

  await testClientRequest((request) {
    request.contentLength = 0;
    request.add(new Uint8List(64 * 1024));
    request.add(new Uint8List(64 * 1024));
    request.add(new Uint8List(64 * 1024));
    request.close();
    request.done.catchError((error) {}, test: (e) => e is HttpException);
    return request.done;
  });
}

Future<Null> testBadResponseClose() async {
  await testClientRequest((request) {
    request.contentLength = 5;
    request.close();
    request.done.catchError((error) {}, test: (e) => e is HttpException);
    return request.done;
  });

  await testClientRequest((request) {
    request.contentLength = 5;
    request.add([0]);
    request.close();
    request.done.catchError((error) {}, test: (e) => e is HttpException);
    return request.done;
  });
}

void main() {
  test("ResponseDone", testResponseDone);
  test("BadResponseAdd", testBadResponseAdd);
  test("BadResponseClose", testBadResponseClose);
}
