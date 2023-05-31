import 'package:args/command_runner.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';
import 'package:pmv/src/entities/dependency.dart';
import 'package:pmv/src/extensions/dependency.dart';
import 'package:pmv/src/file.dart';
import 'package:pubspec/pubspec.dart';

class AnalyseSubPackageCommand extends Command<int> {
  AnalyseSubPackageCommand(this._logger) {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'The path of the output file.',
      defaultsTo: './analyse.txt',
    );
    argParser.addFlag(
      'hide-file',
      negatable: false,
      help: 'Hide file name in result report',
    );
    argParser.addFlag(
      'multi-only',
      negatable: false,
      help: 'In result report, show only package in multiple sub pubspec',
    );
  }

  final Logger _logger;

  @override
  String get name => 'analyse';

  @override
  String get description => 'Analyse package version in sub pubspec';

  @override
  String get invocation => 'pmv analyse -o ./result.txt';

  @override
  Future<int> run() async {
    final output = argResults?['output'] as String;
    final hideFile = argResults?['hide-file'] as bool;
    final multiOnly = argResults?['multi-only'] as bool;

    Map<String, Dependency> allDependencies = {};
    Map<String, Dependency> allDevDependencies = {};
    Map<String, Dependency> allOverrideDependencies = {};

    final progress = _logger.progress('Analyse in progress');

    try {
      // Analyse dependencies
      final pubspecFiles = Glob(join('.', '**', 'pubspec.yaml'));
      for (final entity in pubspecFiles.listSync()) {
        final pubSpec = await PubSpec.loadFile(entity.path);
        final projectName = pubSpec.name ?? 'unknow';

        allDependencies = _analysePubFile(
          projectName: projectName,
          pubSpecDep: pubSpec.dependencies,
          old: allDependencies,
        );
        allDevDependencies = _analysePubFile(
            projectName: projectName,
            pubSpecDep: pubSpec.devDependencies,
            old: allDevDependencies);
        allOverrideDependencies = _analysePubFile(
          projectName: projectName,
          pubSpecDep: pubSpec.dependencyOverrides,
          old: allOverrideDependencies,
        );
      }

      // Write repport
      final file = FileHelper(output, _logger);
      file.write(message: 'Analyse of ${DateTime.now()}\n', append: false);
      file.write(
        message: '\ndependencies:\n',
      );

      await _writeReport(
        file: file,
        dependencies: allDependencies,
        hideFile: hideFile,
        multiOnly: multiOnly,
      );
      file.write(
        message: '\ndev_dependencies:\n',
      );
      await _writeReport(
        file: file,
        dependencies: allDevDependencies,
        hideFile: hideFile,
        multiOnly: multiOnly,
      );
      file.write(
        message: '\noverrides_dependencies:\n',
      );
      await _writeReport(
        file: file,
        dependencies: allOverrideDependencies,
        hideFile: hideFile,
        multiOnly: multiOnly,
      );

      _logger.info('Analyse write in file $output');
      progress.complete('Analyse done!');

      return ExitCode.success.code;
    } on Exception catch (error, st) {
      progress.fail();
      _logger.err(error.toString());
      _logger.detail(st.toString());

      return -1;
    }
  }

  Map<String, Dependency> _analysePubFile({
    required String projectName,
    required Map<String, DependencyReference> pubSpecDep,
    Map<String, Dependency>? old,
  }) {
    // load pubSpec
    final dependencies = old ?? <String, Dependency>{};

    pubSpecDep.forEach((key, DependencyReference value) {
      if (value is! PathReference &&
          value is! SdkReference &&
          value is! GitReference) {
        final version = value.toString();
        dependencies.update(
          key,
          (old) => old.update(file: projectName, version: version),
          ifAbsent: () => Dependency(
            namePub: key,
            versions: [
              DepVersion(
                version,
                [projectName],
              )
            ],
          ),
        );
      }
    });

    return dependencies;
  }

  Future<void> _writeReport({
    required FileHelper file,
    required Map<String, Dependency> dependencies,
    required bool hideFile,
    required bool multiOnly,
  }) async {
    file.startSection();
    dependencies.forEach((key, value) {
      if (!multiOnly && value.isMultiFile) {
        file.write(
          message: '$key:\n',
        );

        file.startSection();

        for (var e in value.versions) {
          file.write(
            message: hideFile
                ? '${e.version}\n'
                : '${e.version} #${e.files.toString()}\n',
          );
        }
        file.endSection();
      }
    });
    file.endSection();
  }
}
