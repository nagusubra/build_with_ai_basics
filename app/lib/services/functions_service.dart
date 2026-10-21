import 'package:cloud_functions/cloud_functions.dart';

import '../models/recipe.dart';

/// Calls into BakeOut's Cloud Functions (`functions/src`).
class FunctionsService {
  FunctionsService({FirebaseFunctions? functions}) : _fn = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _fn;

  Future<void> dismissCherry(String matchId) => _fn.httpsCallable('dismissCherry').call({'matchId': matchId});

  Future<void> confirmDatePlan(String matchId, int version) =>
      _fn.httpsCallable('confirmDatePlan').call({'matchId': matchId, 'version': version});

  /// Deletes the account and everything belonging to it, on the server.
  Future<void> deleteAccount() => _fn
      .httpsCallable('deleteAccount', options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
      .call<void>();

  /// Recipes written for this person; [refresh] asks Cherry for a new set.
  Future<List<Recipe>> myRecipes({bool refresh = false}) async {
    final result = await _fn
        .httpsCallable('getMyRecipes', options: HttpsCallableOptions(timeout: const Duration(seconds: 90)))
        .call({'refresh': refresh});
    final list = (result.data as Map)['recipes'] as List;
    return list.map((r) => Recipe.fromMap((r as Map).cast<String, dynamic>())).toList();
  }
}
