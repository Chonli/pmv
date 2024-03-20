import 'package:args/command_runner.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';
import 'package:pmv/src/extensions/string.dart';
import 'package:pubspec2/pubspec2.dart';

class ApplySubPackageCommand extends Command<int> {
  ApplySubPackageCommand(this._logger) {
    argParser.addOption(
      'source',
      abbr: 's',
      help:
          'The path of the reference pubspec file (pmv_pubspec.yaml by default).',
      defaultsTo: './pmv_pubspec.yaml',
    );
    argParser.addOption(
      'excludePaths',
      help: 'The list of path to exclude',
      defaultsTo: '.fvm,.symlinks',
    );
  }

  final Logger _logger;

  @override
  String get name => 'apply';

  @override
  String get description =>
      'Apply package version specify in reference pubspec in sub pubspec';

  @override
  String get invocation => 'pmv apply -s ./pmv_pubspec.yaml';

  @override
  Future<int> run() async {
    final progress =
        _logger.progress("Apply reference pubspec version in progress");
    final rootFile = argResults?['source'] as String;
    final excludePaths = (argResults?['excludePaths'] as String).split(',');
    int countFile = 0;

    //Read the root pubspec
    final rootPubSpec = await PubSpec.loadFile(rootFile);

    //Apply version to sub pubspec
    final pubspecFiles = Glob(join('.', '**', 'pubspec.yaml'));
    for (final entity in pubspecFiles.listSync()) {
      if (entity.path.isNotExclude(excludePaths)) {
        progress.update('Apply version on file ${entity.path}');
        final pubSpec = await PubSpec.loadFile(entity.path);
        bool updateNeed = false;

        rootPubSpec.dependencies.forEach((key, rootDep) {
          if (pubSpec.dependencies.containsKey(key)) {
            pubSpec.dependencies.update(
              key,
              (_) => rootDep,
            );
            updateNeed = true;
            _logger.detail("$key update");
          }
        });

        rootPubSpec.devDependencies.forEach((key, rootDep) {
          if (pubSpec.devDependencies.containsKey(key)) {
            pubSpec.devDependencies.update(
              key,
              (_) => rootDep,
            );
            updateNeed = true;
            _logger.detail("$key update");
          }
        });

        rootPubSpec.dependencyOverrides.forEach((key, rootDep) {
          if (pubSpec.dependencyOverrides.containsKey(key)) {
            pubSpec.dependencyOverrides.update(
              key,
              (_) => rootDep,
            );
            updateNeed = true;
            _logger.detail("$key update");
          }
        });

        //Update yaml file
        if (updateNeed) {
          _logger.detail("${pubSpec.name} save");
          pubSpec.save(entity.parent);
          countFile++;
        }
      }
    }

    progress.complete('Apply Done! $countFile file updated');
    return ExitCode.success.code;
  }
}
