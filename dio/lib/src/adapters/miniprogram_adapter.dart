import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import '../dio_error.dart';
import '../options.dart';
import '../adapter.dart';
import 'dart:js' as js;

final bool isMiniProgram = (() {
  if (js.context['wx'] != null &&
      (js.context['wx'] as js.JsObject)['request'] != null) {
    return true;
  } else if (js.context['swan'] != null &&
      (js.context['swan'] as js.JsObject)['request'] != null) {
    return true;
  } else {
    return false;
  }
})();

final String _miniProgramScope = (() {
  if (js.context['wx'] != null &&
      (js.context['wx'] as js.JsObject)['request'] != null) {
    return 'wx';
  } else if (js.context['swan'] != null &&
      (js.context['swan'] as js.JsObject)['request'] != null) {
    return 'swan';
  } else {
    return '';
  }
})();

HttpClientAdapter createAdapter() => MiniProgramHttpClientAdapter();

class MiniProgramHttpClientAdapter implements HttpClientAdapter {
  js.JsObject? requestTask;

  /// Whether to send credentials such as cookies or authorization headers for
  /// cross-site requests.
  ///
  /// Defaults to `false`.
  ///
  /// You can also override this value in Options.extra['withCredentials'] for each request
  bool withCredentials = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    var bytes = requestStream != null
        ? await requestStream.reduce((a, b) => Uint8List.fromList([...a, ...b]))
        : null;

    var completer = Completer<ResponseBody>();

    requestTask =
        (js.context[_miniProgramScope] as js.JsObject).callMethod('request', [
      js.JsObject.jsify({
        'url': options.uri.toString(),
        'method': options.method,
        'header': options.headers,
        'responseType': 'arraybuffer',
        'data': (() {
          final contentType = options.headers['content-type'];
          if (contentType is String &&
              contentType.contains('utf-8') &&
              bytes != null) {
            return utf8.decode(bytes);
          }
          return bytes;
        })(),
        'success': (response) {
          if (_miniProgramScope == 'wx') {
            final body = base64.decode((js.context['wx'] as js.JsObject)
                    .callMethod('arrayBufferToBase64', [response['data']])
                as String);
            final headers = <String, String>{};
            if (response['header'] is js.JsObject) {
              _JsMap(response['header'] as js.JsObject).forEach((key, value) {
                if (value is String) {
                  headers[key.toLowerCase()] = value;
                }
              });
            }
            completer.complete(
              ResponseBody.fromBytes(
                body,
                response['statusCode'] as int,
                headers: headers.map((k, v) => MapEntry(k, v.split(','))),
                statusMessage: '',
                isRedirect: response['statusCode'] == 302 ||
                    response['statusCode'] == 301,
              ),
            );
          } else if (_miniProgramScope == 'swan') {
            final body = base64.decode((js.context['Base64'] as js.JsObject)
                .callMethod('encode', [response['data']]) as String);
            final headers = <String, String>{};
            if (response['header'] is js.JsObject) {
              _JsMap(response['header'] as js.JsObject).forEach((key, value) {
                if (value is String) {
                  headers[key.toLowerCase()] = value;
                }
              });
            }
            completer.complete(
              ResponseBody.fromBytes(
                body,
                response['statusCode'] as int,
                headers: headers.map((k, v) => MapEntry(k, v.split(','))),
                statusMessage: '',
                isRedirect: response['statusCode'] == 302 ||
                    response['statusCode'] == 301,
              ),
            );
          }
        },
        'fail': (error) {
          completer.completeError(
            DioError(
              type: DioErrorType.response,
              error: error,
              requestOptions: options,
            ),
            StackTrace.current,
          );
        },
      }),
    ]) as js.JsObject;

    return completer.future;
  }

  /// Closes the client.
  ///
  /// This terminates all active requests.
  @override
  void close({bool force = false}) {
    requestTask?.callMethod('abort');
  }
}

class _JsMap with MapMixin<String, dynamic> {
  final js.JsObject obj;

  _JsMap(this.obj);

  @override
  dynamic operator [](Object? key) {
    if (key == null) return null;
    return obj[key];
  }

  @override
  void operator []=(String key, value) {
    obj[key] = value;
  }

  @override
  void clear() {}

  @override
  Iterable<String> get keys =>
      ((js.context['Object'] as js.JsFunction).callMethod('keys', [obj])
              as js.JsArray)
          .toList()
          .cast<String>();

  @override
  dynamic remove(Object? key) {}
}
