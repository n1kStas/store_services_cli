import 'dart:io';
import 'package:store_services_cli/configurators/base_configurator.dart';

class HmsConfigurator extends BaseConfigurator {
  static const _agconnectPluginId = 'com.huawei.agconnect';
  static const _agconnectVersion = '1.9.1.303';
  static const _mavenRepo =
      'maven { url = uri("https://developer.huawei.com/repo/") }';
  static const _mavenRepoShort =
      'maven(url = "https://developer.huawei.com/repo/")';
  static const _installReferrer =
      'com.android.installreferrer:installreferrer:2.2';

  // Resolution strategy snippet
  static const _resolutionStrategySpy = '''
    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "com.huawei.agconnect") {
                useModule("com.huawei.agconnect:agcp:1.9.1.303")
            }
        }
    }
''';

  static const _proguardRulesContent = '''
# HMS Rules
-ignorewarnings
-keepattributes *Annotation*
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes EnclosingMethod
-keep class com.hianalytics.android.**{*;}
-keep class com.huawei.updatesdk.**{*;}
-keep class com.huawei.hms.**{*;}

## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
-keep class com.huawei.hms.flutter.** { *; }
-repackageclasses
''';

  // ... (buildTypes constants omitted for brevity as they are unchanged) ...
  // Actually, keeping them as is, just inserting resolutionStrategy above proguardRulesContent.

  // NOTE: Previous lines were not shown in context, I need to match carefully.
  // I will just add _resolutionStrategySpy back where it was (around line 13).
  // And update methods.

  // This tool call is tricky with big file. Let's do multiple replace calls or use multi_replace.
  // I will use replace_file_content for the constant first.

  // Standard Flutter default (simplified)
  static const _cleanBuildTypes = '''
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }''';

  Future<void> apply() async {
    print('🔧 [HMS] Applying configuration...');

    await _modifySettingsGradle();
    await _modifyRootBuildGradle();
    await _modifyAppBuildGradle();
    await _modifyManifest();
    await _modifyPubspec();
    await _modifyProguard();
    print('⚠️  Не забудьте добавить android/app/agconnect-services.json');
  }

  Future<void> remove() async {
    print('🧹 [HMS] Removing configuration...');
    await _removeSettingsGradle();
    await _removeRootBuildGradle();
    await _removeAppBuildGradle();
    await _removeManifest();
    await _removePubspec();
    await _removeProguard();
  }

  Future<void> _modifySettingsGradle() async {
    // Extract versions to preserve them
    if (File(settingsGradle).existsSync()) {
      // Just check existence, parsing not needed for injection
    }

    await modifyFile(settingsGradle, 'Settings Gradle', (content) async {
      // Parse existing content to check for GMS/Google Services
      // We assume if 'com.google.gms.google-services' was enabled by GMS configurator,
      // it added a plugin or modification.
      // But actually, GmsConfigurator uses `modifyFile` to *inject* strings.
      // HmsConfigurator uses `modifyFile` to *replace* content with a template.
      // We need to inject HMS logic instead of replacing, OR build a comprehensive template.

      // Better approach: Safe Injection similar to GmsConfigurator.

      var newContent = content;
      bool changed = false;

      // 1. Add Maven Repo to pluginManagement > repositories
      if (!newContent.contains('https://developer.huawei.com/repo/')) {
        // Try precise injection
        if (newContent.contains('gradlePluginPortal()')) {
          newContent = newContent.replaceFirst(
            'gradlePluginPortal()',
            'gradlePluginPortal()\n        maven { url = uri("https://developer.huawei.com/repo/") }',
          );
          changed = true;
        } else if (newContent.contains('repositories {')) {
          newContent = newContent.replaceFirst(
            'repositories {',
            'repositories {\n        maven { url = uri("https://developer.huawei.com/repo/") }',
          );
          changed = true;
        }
      }

      // 2. Add Resolution Strategy
      if (!newContent.contains('com.huawei.agconnect:agcp')) {
        if (newContent.contains('pluginManagement {')) {
          // Insert at end of pluginManagement
          // Finding closing brace is hard without parser.
          // But Gms uses simplified injection.
          // Let's try to find a good anchor.
          if (newContent.contains('repositories {')) {
            // Insert before repositories? No, usually after.
            // Let's replace 'pluginManagement {' with 'pluginManagement {\n$_resolutionStrategySpy' is dangerous if it breaks structure.

            // Let's try replacing the closing brace of pluginManagement?
            // Risky.

            // Let's go with the strategy of: Find where to insert.
            // If we reuse the template approach, we MUST include what we found.

            // Let's revert to the Template approach but make it smarter.
            // No, user wants stability. Injection is safer for hybrid.

            final repoBlock = RegExp(r'repositories \{[^}]+\}');
            final match = repoBlock.firstMatch(newContent);
            if (match != null) {
              newContent = newContent.replaceRange(
                match.end,
                match.end,
                '\n$_resolutionStrategySpy',
              );
              changed = true;
            }
          }
        }
      }

      // 3. Apply Plugin
      if (!newContent.contains('id("$_agconnectPluginId")')) {
        if (newContent.contains('plugins {')) {
          newContent = newContent.replaceFirst(
            'plugins {',
            'plugins {\n    id("$_agconnectPluginId") version "$_agconnectVersion" apply false',
          );
          changed = true;
        }
      }

      return changed ? newContent : null;
    });
  }

  Future<void> _removeSettingsGradle() async {
    await modifyFile(settingsGradle, 'Settings Gradle', (content) async {
      var newContent = content
          .replaceFirst('\n        $_mavenRepo', '')
          .replaceFirst(_mavenRepo, '');

      // Remove resolution strategy (handle potential leading newline)
      newContent = newContent
          .replaceFirst('\n$_resolutionStrategySpy', '')
          .replaceFirst(_resolutionStrategySpy, '');

      // Remove plugin
      newContent = newContent.replaceFirst(
        '\n    id("$_agconnectPluginId") version "$_agconnectVersion" apply false',
        '',
      );

      return newContent;
    });
  }

  Future<void> _modifyRootBuildGradle() async {
    await modifyFile(rootBuildGradle, 'Root Gradle', (content) async {
      // We will mostly OVERWRITE or ensure the structure matches the user request.
      // User want: imports, allprojects, buildscript, dir, subprojects, clean.

      // If the file is already roughly in this structure (has buildscript), we might just ensure HMS lines.
      // But user said "sdelai tak chtoby poluchilos tak".
      // To be safe and avoid duplicates, I will reconstruct the file.

      var newContent = content;
      bool changed = false;

      // 1. Add Maven Repo
      if (!newContent.contains('https://developer.huawei.com/repo/')) {
        if (newContent.contains('repositories {')) {
          // Basic injection: Add to all occurrences (buildscript and allprojects)
          newContent = newContent.replaceAll(
            'repositories {',
            'repositories {\n        maven(url = "https://developer.huawei.com/repo/")',
          );
          changed = true;
        }
      }

      // 2. Add Classpath
      if (!newContent.contains('com.huawei.agconnect:agcp')) {
        if (newContent.contains('dependencies {')) {
          newContent = newContent.replaceFirst(
            'dependencies {',
            'dependencies {\n        classpath("com.huawei.agconnect:agcp:$_agconnectVersion")',
          );
          changed = true;
        }
      }

      // 3. Add AIDL Fix
      const aidlFix = '''

// Fix for Huawei Ads AIDL compilation per hms-flutter-plugin/#396
subprojects {
    if (project.name == "huawei_ads" || project.group.toString() == "com.huawei.hms.flutter.ads") {
        val configureAidl = {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.buildFeatures?.aidl = true
        }
        if (project.state.executed) {
            configureAidl()
        } else {
            project.afterEvaluate { configureAidl() }
        }
    }
}
''';
      if (!newContent.contains('Fix for Huawei Ads AIDL compilation')) {
        newContent += aidlFix;
        changed = true;
      }

      return changed ? newContent : null;
    });
  }

  Future<void> _removeRootBuildGradle() async {
    await modifyFile(rootBuildGradle, 'Root Gradle', (content) async {
      var newContent = content;

      // Remove HMS Repo from allprojects
      newContent = newContent
          .replaceFirst('\n        $_mavenRepoShort', '')
          .replaceFirst(_mavenRepoShort, '');

      // Remove HMS Plugin from plugins (if legacy style or inside plugins {})
      newContent = newContent.replaceFirst(
        '\n    id("$_agconnectPluginId") version "$_agconnectVersion" apply false',
        '',
      );

      // Remove AIDL Fix
      const aidlFix = '''

// Fix for Huawei Ads AIDL compilation per hms-flutter-plugin/#396
subprojects {
    if (project.name == "huawei_ads" || project.group.toString() == "com.huawei.hms.flutter.ads") {
        val configureAidl = {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.buildFeatures?.aidl = true
        }
        if (project.state.executed) {
            configureAidl()
        } else {
            project.afterEvaluate { configureAidl() }
        }
    }
}
''';
      if (newContent.contains('Fix for Huawei Ads AIDL compilation')) {
        // Try exact match first
        newContent = newContent.replaceFirst(aidlFix, '');
        // Fallback regex if needed
        if (newContent.contains('Fix for Huawei Ads AIDL compilation')) {
          newContent = newContent.replaceAll(
            RegExp(
              r'(\n)*\/\/ Fix for Huawei Ads AIDL compilation(.|\n)*?}\n}\n',
            ),
            '',
          );
        }
      }

      // Remove imported Directory class if present
      newContent = newContent.replaceFirst(
        'import org.gradle.api.file.Directory\n',
        '',
      );
      newContent = newContent.replaceFirst(
        'import org.gradle.api.file.Directory',
        '',
      );

      // Remove buildscript block (Aggressive removal if it looks like ours)
      // We look for buildscript that contains our classpath
      if (newContent.contains('buildscript {') &&
          newContent.contains('com.huawei.agconnect:agcp')) {
        // We'll remove the HMS classpath
        newContent = newContent.replaceFirst(
          RegExp(r'classpath\("com.huawei.agconnect:agcp:[^"]+"\)\n?'),
          '',
        );
        // usage of maven repo in buildscript
        newContent = newContent.replaceFirst(
          RegExp(r'maven\(url = "https://developer.huawei.com/repo/"\)\n?'),
          '',
        );

        // If we want to completely revert the "Legacy Buildscript" injection:
        // We should check if we should remove the whole block.
        // Given the user manually added it, maybe they want it gone.
        // But I can't be 100% sure without a parser.
        // I will leave it at removing HMS specific lines inside it for safety, unless I can match the template.

        // Let's try to match the template keys
        // If it contains "google()", "mavenCentral()", "gradlePluginPortal()" and dependencies block...
        // I'll stick to removing hms lines. If empty lines remain, so be it, safer than deleting user's custom buildscript.
      }

      return newContent;
    });
  }

  Future<void> _modifyAppBuildGradle() async {
    await modifyFile(appBuildGradle, 'App Gradle', (content) async {
      var newContent = content;
      bool changed = false;

      // 1. Apply Plugin
      if (!newContent.contains('id("$_agconnectPluginId")')) {
        // Try to add after com.android.application to ensure correct order
        if (newContent.contains('id("com.android.application")')) {
          newContent = newContent.replaceFirst(
            'id("com.android.application")',
            'id("com.android.application")\n    id("$_agconnectPluginId")',
          );
          changed = true;
        } else if (newContent.contains('plugins {')) {
          // Fallback if android plugin not found explicitly (rare)
          newContent = newContent.replaceFirst(
            'plugins {',
            'plugins {\n    id("$_agconnectPluginId")',
          );
          changed = true;
        }
      }

      // 2. Add Dependencies
      if (!newContent.contains(_installReferrer)) {
        if (newContent.contains('dependencies {')) {
          newContent = newContent.replaceFirst(
            'dependencies {',
            'dependencies {\n    implementation("$_installReferrer")',
          );
          changed = true;
        } else {
          newContent +=
              '\n\ndependencies {\n    implementation("$_installReferrer")\n}';
          changed = true;
        }
      }

      // 3. Replace buildTypes
      // Note: We commented out 'signingConfig = ...' in _hmsBuildTypes to prevent crash if not defined.
      // If user wants it, they must ensure they have it or uncomment it manually.
      // But user REQUESTED this logic. Let's try to match user intent BUT safest way.
      // User snippet: signingConfig = signingConfigs.getByName("release")
      // I will uncomment it but warning printed? No, user explicitly asked code.
      // Let's use the USER's snippet but with a small check? No, we replace block.

      // Re-defining _hmsBuildTypes with unlocked signingConfig for user request compliance:
      const userRequestedBuildTypes = '''
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release") 
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            isDebuggable = true
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }''';

      final replaced = replaceBlock(
        newContent,
        'buildTypes',
        userRequestedBuildTypes,
      );
      if (replaced != null && replaced != newContent) {
        newContent = replaced;
        changed = true;
      }

      return changed ? newContent : null;
    });
  }

  Future<void> _removeAppBuildGradle() async {
    await modifyFile(appBuildGradle, 'App Gradle', (content) async {
      var newContent = content;

      // Remove plugin and deps
      if (newContent.contains(_agconnectPluginId)) {
        newContent = newContent.replaceFirst(
          '\n    id("$_agconnectPluginId")',
          '',
        );
      }
      if (newContent.contains(_installReferrer)) {
        newContent = newContent.replaceFirst(
          '\n    implementation("$_installReferrer")',
          '',
        );
      }

      // Restore clean buildTypes
      // We assume if we are removing HMS, we want to go back to clean state.
      // This is risky if GMS relies on it? GMS doesn't care about buildTypes usually.
      // But 'clean' action is destructive by definition.

      final replaced = replaceBlock(newContent, 'buildTypes', _cleanBuildTypes);
      if (replaced != null) {
        newContent = replaced;
      }

      return newContent;
    });
  }

  Future<void> _modifyManifest() async {
    await modifyFile(manifest, 'Manifest', (content) async {
      var newContent = content;
      bool changed = false;

      // 0. Ensure xmlns:tools is present
      if (!newContent.contains('xmlns:tools')) {
        newContent = newContent.replaceFirst(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android"',
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android" xmlns:tools="http://schemas.android.com/tools"',
        );
        changed = true;
      }

      // Permissions to REMOVE
      final permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
        '<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />',
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />',
        '<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" tools:node="remove" />',
        '<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>',
        '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" tools:node="remove" />',
      ];

      final appTagIndex = newContent.indexOf('<application');
      if (appTagIndex != -1) {
        for (var perm in permissions) {
          if (!newContent.contains(perm)) {
            newContent = newContent.replaceRange(
              appTagIndex,
              appTagIndex,
              '$perm\n    ',
            );
            changed = true;
          }
        }

        final appEndIndex = newContent.indexOf('</application>');
        if (appEndIndex != -1) {
          const receivers = '''
        <receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationBootEventReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
        <receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationScheduledPublisher" android:exported="false" />
        <receiver android:name="com.huawei.hms.flutter.push.receiver.BackgroundMessageBroadcastReceiver" android:exported="false">
            <intent-filter>
                <action android:name="com.huawei.hms.flutter.push.receiver.BACKGROUND_REMOTE_MESSAGE" />
            </intent-filter>
        </receiver>
''';
          if (!newContent.contains('HmsLocalNotificationBootEventReceiver')) {
            newContent = newContent.replaceRange(
              appEndIndex,
              appEndIndex,
              receivers,
            );
            changed = true;
          }
        }
      }

      // Queries
      if (!newContent.contains('com.huawei.hms.core.aidlservice')) {
        const query = '''
    <queries>
        <intent>
            <action android:name="com.huawei.hms.core.aidlservice" />
        </intent>
    </queries>
''';
        final manifestEnd = newContent.indexOf('</manifest>');
        if (manifestEnd != -1) {
          newContent = newContent.replaceRange(manifestEnd, manifestEnd, query);
          changed = true;
        }
      }

      return changed ? newContent : null;
    });
  }

  Future<void> _removeManifest() async {
    await modifyFile(manifest, 'Manifest', (content) async {
      var newContent = content;
      final permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
        '<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />',
        '<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" tools:node="remove" />',
        '<uses-permission android:name="android.permission.QUERY_ALL_PACKAGES" tools:node="remove" />',
      ];
      for (var perm in permissions) {
        newContent = newContent
            .replaceFirst('$perm\n    ', '')
            .replaceFirst(perm, '');
      }

      // Remove Receivers logic
      const receivers = '''
        <receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationBootEventReceiver" android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
            </intent-filter>
        </receiver>
        <receiver android:name="com.huawei.hms.flutter.push.receiver.local.HmsLocalNotificationScheduledPublisher" android:exported="false" />
        <receiver android:name="com.huawei.hms.flutter.push.receiver.BackgroundMessageBroadcastReceiver" android:exported="false">
            <intent-filter>
                <action android:name="com.huawei.hms.flutter.push.receiver.BACKGROUND_REMOTE_MESSAGE" />
            </intent-filter>
        </receiver>
''';
      // Attempt clean removal
      newContent = newContent.replaceFirst(receivers, '');

      const query = '''
    <queries>
        <intent>
            <action android:name="com.huawei.hms.core.aidlservice" />
        </intent>
    </queries>
''';
      newContent = newContent.replaceFirst(query, '');

      return newContent;
    });
  }

  Future<void> _modifyPubspec() async {
    await modifyFile(pubspec, 'Pubspec', (content) async {
      var newContent = content;
      bool changed = false;

      const deps = '''
  huawei_push:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-push
  huawei_ads:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-ads
  huawei_hmsavailability:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-availability
''';

      if (newContent.contains('dependencies:')) {
        if (!newContent.contains('huawei_push:')) {
          newContent = newContent.replaceFirst(
            'dependencies:',
            'dependencies:\n$deps',
          );
          changed = true;
        }
        // permission_handler добавляем отдельно, только если его ещё нет,
        // чтобы не создать дубликат ключа в pubspec.yaml.
        if (!newContent.contains('permission_handler:')) {
          newContent = newContent.replaceFirst(
            'dependencies:',
            'dependencies:\n  permission_handler: ^12.0.1',
          );
          changed = true;
        }
      }
      return changed ? newContent : null;
    });
  }

  Future<void> _removePubspec() async {
    await modifyFile(pubspec, 'Pubspec', (content) async {
      const depsNew = '''
  huawei_push:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-push
  huawei_ads:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-ads
  huawei_hmsavailability:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-availability
  permission_handler: ^12.0.1
''';

      const depsOld = '''
  huawei_push:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-push
  huawei_ads:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-ads
  huawei_hmsavailability:
    git:
      url: https://github.com/Mr-KrY4k/hms-flutter-plugin.git
      ref: hms_push_flutter_3.29
      path: flutter-hms-availability
''';

      var newContent = content;
      // Try remove new deps
      newContent = newContent
          .replaceFirst('\n$depsNew', '')
          .replaceFirst(depsNew, '');
      // Try remove old deps (if new removal didn't happen or partial match issues)
      newContent = newContent
          .replaceFirst('\n$depsOld', '')
          .replaceFirst(depsOld, '');

      return newContent;
    });
  }

  Future<void> _modifyProguard() async {
    // Check if file exists, if not create empty?
    // basic modifyFile expects file to exist.
    // Use File() check? BaseConfigurator has modifyFile, but not file creation logic usually.
    // But modifyFile reads file.
    // We can use dart:io here?
    // Or just use dcli.

    // We need to import dart:io or use dcli.
    // BaseConfigurator imports dcli.
    if (!File(proguardRules).existsSync()) {
      File(proguardRules).createSync(recursive: true);
    }

    await modifyFile(proguardRules, 'Proguard Rules', (content) async {
      if (!content.contains('com.huawei.hms')) {
        return content + '\n' + _proguardRulesContent;
      }
      return null;
    });
  }

  Future<void> _removeProguard() async {
    await modifyFile(proguardRules, 'Proguard Rules', (content) async {
      if (content.contains('com.huawei.hms')) {
        return content.replaceFirst('\n' + _proguardRulesContent, '');
      }
      return null;
    });
  }
}
