import 'package:cloud_functions/cloud_functions.dart';

/// Calls into BakeOut's Cloud Functions (`functions/src`).
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions}) : _fn = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _fn;

  Future<void> dismissCherry(String matchId) => _fn.httpsCallable('dismissCherry').call({'matchId': matchId});
}
