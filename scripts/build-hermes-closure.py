"""Build Closure's JVM library and typed runtime resources from source."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--java', required=True)
parser.add_argument('--javac', required=True)
parser.add_argument('--jar', required=True)
parser.add_argument('--protoc', required=True)
parser.add_argument('--shell', required=True)
parser.add_argument('--runtime-input', type=Path, action='append', default=[])
parser.add_argument('--processor-input', type=Path, action='append', default=[])
parser.add_argument('--ant-input', type=Path, required=True)
parser.add_argument('--compiler-version', choices=('20220502', '20230206'), default='20220502')
args = parser.parse_args()
root = Path.cwd()
work = root / 'guix-closure-build'
work.mkdir()
classes = work / 'classes'
classes.mkdir()
generated = work / 'generated-protos'
generated.mkdir()
(work / 'generated-autovalue').mkdir()


def jars(inputs):
    result = []
    for directory in inputs:
        files = sorted(directory.rglob('*.jar'))
        if not files:
            raise ValueError(f'Missing compiled Java library: {directory}')
        if any(file.name.endswith('-sources.jar') for file in files):
            raise ValueError(f'Source archive cannot be a compiled classpath input: {directory}')
        result.extend(str(file) for file in files)
    return result


runtime = jars(args.runtime_input)
ant = list(args.ant_input.rglob('ant.jar'))
if len(ant) != 1:
    raise ValueError(f'Expected one compiled Ant runtime: {ant}')
runtime.append(str(ant[0]))
processor = jars(args.processor_input)

# Regenerate every Java protocol used by the upstream compiler library.
protos = sorted((root / 'src').rglob('*.proto'))
expected_protos = {
    'src/com/google/debugging/sourcemap/proto/mapping.proto',
    'src/com/google/javascript/jscomp/conformance/conformance.proto',
    'src/com/google/javascript/jscomp/instrumentation/reporter/proto/profile.proto',
    *{'src/com/google/javascript/rhino/typed_ast/' + name for name in
      ('optimization_jsdoc.proto', 'source_file.proto', 'typed_ast.proto', 'types.proto')},
}
if {file.relative_to(root).as_posix() for file in protos} != expected_protos:
    raise ValueError('Unexpected Closure protocol inventory')
subprocess.run([args.protoc, f'--proto_path={root}', f'--java_out={generated}',
                *map(str, protos)], check=True)

if args.compiler_version == '20230206':
    template = root / 'src/com/google/javascript/jscomp/CommandLineRunnerVersion.template'
    source = root / 'src/com/google/javascript/jscomp/CommandLineRunnerVersion.java'
    text = template.read_text()
else:
    source = root / 'src/com/google/javascript/jscomp/CommandLineRunner.java'
    text = source.read_text()
if text.count('inlineDefine_COMPILER_VERSION') != 1:
    raise ValueError('Unexpected compiler version template')
version_literal = 'v' + args.compiler_version
if args.compiler_version == '20220502':
    version_literal = '"' + version_literal + '"'
source.write_text(text.replace('inlineDefine_COMPILER_VERSION', version_literal))

# Match compiler_lib_no_runtime_libs' authored source selection.
excluded = {'debugger', 'j2clbuild', 'j2cl', 'testing', 'webservice'}
sources = []
for file in sorted((root / 'src/com/google').rglob('*.java')):
    parts = file.relative_to(root / 'src').parts[:-1]
    if any(part in excluded or part.startswith('super') for part in parts):
        continue
    sources.append(file)
sources.extend(sorted(generated.rglob('*.java')))
source_list = work / 'sources.txt'
source_list.write_text('\n'.join(map(str, sources)) + '\n')
subprocess.run([
    args.javac, '-J-Xmx2g', '--release', '11', '-encoding', 'UTF-8',
    '-classpath', os.pathsep.join(runtime),
    '-processorpath', os.pathsep.join(processor),
    '-s', str(work / 'generated-autovalue'), '-d', str(classes),
    '@' + str(source_list),
], check=True)

for file in sorted((root / 'src').rglob('*.properties')):
    destination = classes / file.relative_to(root / 'src')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(file, destination)
with zipfile.ZipFile(classes / 'externs.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for file in sorted((root / 'externs').rglob('*.js')):
        entry = zipfile.ZipInfo(file.relative_to(root / 'externs').as_posix(),
                                date_time=(1980, 1, 1, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, file.read_bytes())

# This is upstream's build-time typed-AST generation, not a functional test.
js_root = root / 'src/com/google/javascript/jscomp/js'
js_sources = [file for file in sorted(js_root.rglob('*.js'))
              if file.name not in {'runtime_type_check.js', 'build_polyfill_table.js'}]
typedast = classes / 'runtime_libs.typedast'
subprocess.run([
    args.java, '-Xmx2g', '-cp', os.pathsep.join([str(classes), *runtime]),
    'com.google.javascript.jscomp.CommandLineRunner',
    '--checks_only', '--strict_mode_input', '--env=CUSTOM',
    '--language_out=ES_NEXT', '--inject_libraries=false',
    '--jscomp_error=checkTypes', '--jscomp_off=uselessCode',
    '--typed_ast_output_file__INTENRNAL_USE_ONLY=' + str(typedast),
    *['--js=' + str(file) for file in js_sources],
], check=True)
if not typedast.is_file() or not typedast.stat().st_size:
    raise ValueError('Missing generated runtime typed AST')
resources = [*js_sources, js_root / 'polyfills.txt']
if args.compiler_version == '20220502':
    resources.append(js_root / 'runtime_type_check.js')
for file in resources:
    destination = classes / file.relative_to(root / 'src')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(file, destination)

share = args.output / 'share/java'
share.mkdir(parents=True)
output_jar = share / 'closure-compiler.jar'
subprocess.run([args.jar, 'cf', str(output_jar), '-C', str(classes), '.'], check=True)
commands = {
    'closure-compiler': 'com.google.javascript.jscomp.CommandLineRunner',
    'closure-linter': 'com.google.javascript.jscomp.LinterMain',
    'closure-instrumentation-reporter':
        'com.google.javascript.jscomp.instrumentation.reporter.ProductionInstrumentationReporter',
}
classpath = os.pathsep.join([str(output_jar), *runtime])
bin_dir = args.output / 'bin'
bin_dir.mkdir()
for name, main in commands.items():
    file = bin_dir / name
    file.write_text('#!' + args.shell + '\nexec ' + shlex.quote(args.java)
                    + ' -cp ' + shlex.quote(classpath) + ' ' + main + ' "$@"\n')
    file.chmod(0o755)
print(f'Built {len(sources)} Java source files and {len(js_sources)} typed runtime sources')
