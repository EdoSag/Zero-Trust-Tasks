import 'package:http/http.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class GoogleAuthClient extends BaseClient {
  GoogleAuthClient(this._headers);

  final Map<String, String> _headers;

  final Client _client = Client();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
