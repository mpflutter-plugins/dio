import '../dio_mixin.dart';
import '../options.dart';
import '../dio.dart';
import '../adapters/browser_adapter.dart';
import '../adapters/taro_adapter.dart' as taro;

Dio createDio([BaseOptions? options]) => DioForBrowser(options);

class DioForBrowser with DioMixin implements Dio {
  /// Create Dio instance with default [Options].
  /// It's mostly just one Dio instance in your application.
  DioForBrowser([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    httpClientAdapter =
        taro.isTaro ? taro.TaroHttpClientAdapter() : BrowserHttpClientAdapter();
  }
}
