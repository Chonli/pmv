import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:pubspec2/pubspec2.dart';

class UpgradeRootPackageCommand extends Command<int> {
  UpgradeRootPackageCommand(this._logger) {
    argParser.addOption(
      'source',
      abbr: 's',
      help:
          'The path of the reference pubspec file (pmv_pubspec.yaml by default).',
      defaultsTo: './pmv_pubspec.yaml',
    );
    argParser.addFlag(
      'upgrade-overrides',
      help: 'Force upgrade version of dependency_overrides',
    );
  }

  final Logger _logger;

  @override
  String get name => 'upgrade';

  @override
  String get description => 'Upgrade package version in reference pubspec';

  @override
  String get invocation => 'pmv upgrade -s ./pmv_pubspec.yaml';

  @override
  Future<int> run() async {
    final pubUpdater = PubUpdater();
    final progress = _logger
        .progress("Upgrade reference pubspec package version in progress");
    final rootFile = argResults?['source'] as String;
    final forceUpgradeOverrides = argResults?['upgrade-overrides'] as bool;

    //Read the root pubspec
    final rootPubSpec = await PubSpec.loadFile(rootFile);

    //Apply version to sub pubspec
    await Future.forEach(rootPubSpec.dependencies.entries, (entry) async {
      final key = entry.key;
      final latestVersion = await pubUpdater.getLatestVersion(key);
      progress.update('$key new version: $latestVersion');
      rootPubSpec.dependencies.update(
        key,
        (value) => HostedReference.fromJson('^$latestVersion'),
      );
    });

    await Future.forEach(rootPubSpec.devDependencies.entries, (entry) async {
      final key = entry.key;
      final latestVersion = await pubUpdater.getLatestVersion(key);
      progress.update('$key new version: $latestVersion');
      rootPubSpec.devDependencies.update(
        key,
        (value) => HostedReference.fromJson('^$latestVersion'),
      );
    });

    if (forceUpgradeOverrides) {
      await Future.forEach(rootPubSpec.dependencyOverrides.entries,
          (entry) async {
        final key = entry.key;
        final latestVersion = await pubUpdater.getLatestVersion(key);
        progress.update('$key new version: $latestVersion');
        rootPubSpec.dependencyOverrides.update(
          key,
          (value) => HostedReference.fromJson('^$latestVersion'),
        );
      });
    }

    // Save in file
    const pubSpecName = './pubspec.yaml';
    if (File(pubSpecName).existsSync()) {
      File(pubSpecName).renameSync('$pubSpecName.bak');
    }

    await rootPubSpec.save(Directory.current);
    File(pubSpecName).renameSync(rootFile);

    if (File('$pubSpecName.bak').existsSync()) {
      File('$pubSpecName.bak').renameSync(pubSpecName);
    }

    progress.complete('Upgrade Done!');

    return ExitCode.success.code;
  }
}
