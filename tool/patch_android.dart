// Prépare le projet Android généré par `flutter create` :
//  - ajoute les permissions réseau (indispensables pour l'APK release) ;
//  - autorise le HTTP en clair (serveur de développement sur le réseau local) ;
//  - déclare les intentions « ouvrir un lien http/https » (lien vers l'espace web) ;
//  - donne son nom à l'application ;
//  - supprime le test d'exemple généré par Flutter.
//
// Le script peut être relancé sans risque : chaque modification n'est faite qu'une fois.
//
// Usage : dart run tool/patch_android.dart
import 'dart:io';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln(
      'AndroidManifest.xml introuvable. Lancez d\'abord :\n'
      '  flutter create --platforms=android --project-name caisse_offline .',
    );
    exit(1);
  }

  var xml = manifest.readAsStringSync();

  const permissions = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
  ];
  for (final permission in permissions.reversed) {
    if (!xml.contains(permission)) {
      xml = xml.replaceFirst(
        '<application',
        '<uses-permission android:name="$permission"/>\n    <application',
      );
    }
  }

  if (!xml.contains('android:scheme="https"')) {
    xml = xml.replaceFirst(
      '<application',
      '<queries>\n'
      '        <intent>\n'
      '            <action android:name="android.intent.action.VIEW"/>\n'
      '            <data android:scheme="https"/>\n'
      '        </intent>\n'
      '        <intent>\n'
      '            <action android:name="android.intent.action.VIEW"/>\n'
      '            <data android:scheme="http"/>\n'
      '        </intent>\n'
      '    </queries>\n'
      '    <application',
    );
  }

  if (!xml.contains('usesCleartextTraffic')) {
    xml = xml.replaceFirst(
      '<application',
      '<application\n        android:usesCleartextTraffic="true"',
    );
  }

  xml = xml.replaceFirst(
    RegExp(r'android:label="[^"]*"'),
    'android:label="Ma Caisse"',
  );
  manifest.writeAsStringSync(xml);

  final sample = File('test/widget_test.dart');
  if (sample.existsSync() && sample.readAsStringSync().contains('MyApp')) {
    sample.deleteSync();
  }

  stdout.writeln('Android prêt : permissions réseau, liens web, HTTP en clair (dev), nom de l\'application.');
}
