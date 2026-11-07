import 'package:flutter/foundation.dart';

/// Signal global : « les données locales ont changé, rechargez-vous ».
/// Déclenché après chaque écriture locale et après chaque synchronisation.
class DataEvents extends ChangeNotifier {
  void changed() => notifyListeners();
}
