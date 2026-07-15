import 'package:store_services_cli/configurators/base_configurator.dart';

class RmsConfigurator extends BaseConfigurator {
  // --- Constants for RMS (RuStore) ---
  static const _projectIdMeta =
      '<meta-data android:name="ru.rustore.sdk.pushclient.project_id" android:value="RUSTORE_PROJECT_ID" />';

  // RuStore Push SDK obfuscates its Parcelable classes; keep them.
  static const _proguardRule =
      '-keep public class com.vk.push.** extends android.os.Parcelable';

  // flutter_rustore_push provides Push; google_api_availability lets the
  // hybrid StoreService detect Google Play services before falling back to
  // RuStore. advertising_id (GAID) is the RuStore-ads fallback when no OAID.
  static const _deps = [
    'flutter_rustore_push: ^7.2.0',
    'google_api_availability: ^5.0.0',
    'advertising_id: ^2.7.1',
  ];

  // RuStore ads fall back to OAID (Huawei) → GAID (Google). In Hybrid mode
  // huawei_ads is already added by the HMS configurator; for a standalone RMS
  // build we add it here so rms_service.dart compiles. Guarded to avoid dupes.
  static const _huaweiAdsGitDep = '''
  huawei_ads:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-ads''';

  Future<void> apply() async {
    print('🔧 [RMS] Applying configuration...');
    await _modifyPubspec();
    await _modifyManifest();
    await _modifyProguard();
    print(
      '⚠️  Не забудьте заменить RUSTORE_PROJECT_ID в AndroidManifest.xml '
      'на project_id из консоли RuStore',
    );
  }

  Future<void> remove() async {
    print('🧹 [RMS] Removing configuration...');
    await _removePubspec();
    await _removeManifest();
    await _removeProguard();
  }

  Future<void> _modifyPubspec() async {
    await modifyFile(pubspec, 'Pubspec', (content) async {
      var newContent = content;
      bool changed = false;

      if (newContent.contains('dependencies:')) {
        for (final dep in _deps) {
          final depName = dep.split(':')[0];
          if (!newContent.contains('$depName:')) {
            newContent = newContent.replaceFirst(
              'dependencies:',
              'dependencies:\n  $dep',
            );
            changed = true;
          }
        }
        if (!newContent.contains('huawei_ads:')) {
          newContent = newContent.replaceFirst(
            'dependencies:',
            'dependencies:\n$_huaweiAdsGitDep',
          );
          changed = true;
        }
      }
      return changed ? newContent : null;
    });
  }

  Future<void> _removePubspec() async {
    await modifyFile(pubspec, 'Pubspec', (content) async {
      var newContent = content;
      bool changed = false;
      for (final dep in _deps) {
        if (newContent.contains(dep)) {
          newContent = newContent
              .replaceFirst('\n  $dep', '')
              .replaceFirst(dep, '');
          changed = true;
        }
      }
      // Only removes the standalone-RMS huawei_ads block; in Hybrid the HMS
      // configurator owns (and already removed) its own huawei block.
      if (newContent.contains(_huaweiAdsGitDep)) {
        newContent = newContent
            .replaceFirst('\n$_huaweiAdsGitDep', '')
            .replaceFirst(_huaweiAdsGitDep, '');
        changed = true;
      }
      return changed ? newContent : null;
    });
  }

  Future<void> _modifyManifest() async {
    await modifyFile(manifest, 'Manifest', (content) async {
      if (content.contains('ru.rustore.sdk.pushclient.project_id')) {
        return null;
      }
      final appEndIndex = content.indexOf('</application>');
      if (appEndIndex == -1) return null;
      return content.replaceRange(
        appEndIndex,
        appEndIndex,
        '    $_projectIdMeta\n    ',
      );
    });
  }

  Future<void> _removeManifest() async {
    await modifyFile(manifest, 'Manifest', (content) async {
      if (!content.contains('ru.rustore.sdk.pushclient.project_id')) {
        return null;
      }
      return content
          .replaceFirst('    $_projectIdMeta\n    ', '')
          .replaceFirst(_projectIdMeta, '');
    });
  }

  Future<void> _modifyProguard() async {
    await modifyFile(proguardRules, 'Proguard', (content) async {
      if (content.contains(_proguardRule)) return null;
      return '$content\n\n# RuStore Push\n$_proguardRule\n';
    });
  }

  Future<void> _removeProguard() async {
    await modifyFile(proguardRules, 'Proguard', (content) async {
      if (!content.contains(_proguardRule)) return null;
      return content
          .replaceFirst('\n\n# RuStore Push\n$_proguardRule\n', '')
          .replaceFirst('$_proguardRule\n', '')
          .replaceFirst(_proguardRule, '');
    });
  }
}
