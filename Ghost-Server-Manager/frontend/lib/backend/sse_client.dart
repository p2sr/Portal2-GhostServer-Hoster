//! Adapted from https://pub.dev/packages/flutter_client_sse

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SseEvent {
  String? id;
  String? event;
  String? data;

  SseEvent({this.id, this.event, this.data});
}

class SseClient {
  var lineRegex = RegExp(r'^([^:]*)(?::)?(?: )?(.*)?$');

  SseClient._(this._client, this._responseStream) {
    _responseStream.stream
        .transform(Utf8Decoder())
        .transform(LineSplitter())
        .listen(_processStream);
  }

  final http.Client _client;
  final http.StreamedResponse _responseStream;

  final StreamController<SseEvent> _streamController = StreamController();

  SseEvent currentEvent = SseEvent();

  Stream<SseEvent> get stream => _streamController.stream;

  static Future<SseClient> connect({
    required String url,
    required Map<String, String> headers,
  }) async {
    var request = http.Request("GET", Uri.parse(url));
    request.headers.addAll(headers);

    var httpClient = http.Client();
    var response = await httpClient.send(request);

    return SseClient._(httpClient, response);
  }

  void close() {
    _streamController.close();
    _client.close();
  }

  void _processStream(String line) {
    if (line.isEmpty) {
      // complete event has been received
      _streamController.add(currentEvent);
      currentEvent = SseEvent();
      return;
    }

    /// Get the match of each line through the regex
    var match = lineRegex.firstMatch(line)!;
    var field = match.group(1);
    if (field!.isEmpty) return;

    var value = '';
    if (field == 'data') {
      value = line.substring(6);
    } else {
      value = match.group(2) ?? '';
    }

    switch (field) {
      case 'event':
        currentEvent.event = value;
        break;
      case 'data':
        currentEvent.data = '${currentEvent.data ?? ''}$value\n';
        break;
      case 'id':
        currentEvent.id = value;
        break;
    }
  }
}
