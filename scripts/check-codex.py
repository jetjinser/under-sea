#!/usr/bin/env python3
"""Check the installed Codex CLI and policy evaluator without model requests."""
import argparse, json, os, subprocess, tempfile
from pathlib import Path
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('package',type=Path,help='Guix output directory')
parser.add_argument('--sandbox',action='store_true',help='Also execute Guix ripgrep inside the Linux sandbox; requires user namespaces and a writable working directory outside /tmp')
args=parser.parse_args(); package=args.package.resolve(); program=package/'bin/codex'
expected_version=json.loads((package/'codex-package.json').read_text())['version']
with tempfile.TemporaryDirectory(prefix='.codex-check-',dir=Path.cwd() if args.sandbox else None) as temporary:
    env=os.environ.copy(); env['CODEX_HOME']=temporary
    def run(*arguments):
        result=subprocess.run([str(program),*arguments],env=env,text=True,capture_output=True,check=True,timeout=60)
        return result.stdout
    assert run('--version').strip().split()[-1]==expected_version
    for arguments in [('--help',),('exec','--help'),('app-server','--help'),('sandbox','--help')]:run(*arguments)
    rule=Path(temporary)/'test.rules'
    rule.write_text('prefix_rule(pattern=["git", "status"], decision="allow")\nprefix_rule(pattern=["git", "push"], decision="forbidden")\n')
    for subcommand,expected in [('status','allow'),('push','forbidden')]:
        result=json.loads(run('execpolicy','check','--rules',str(rule),'--','git',subcommand))
        assert result['decision']==expected,result
    catalog=package/'share/codex/guix-models-direct.json'
    models=json.loads(catalog.read_text())['models']
    assert models and all(model.get('tool_mode') not in ('code_mode','code_mode_only') for model in models)
    run('-c','model_catalog_json='+json.dumps(str(catalog)),'features','list')
    assert os.access(package/'bin/codex-linux-sandbox',os.X_OK)
    assert os.access(package/'codex-resources/bwrap',os.X_OK)
    assert os.access(package/'codex-resources/rg',os.X_OK)
    for helper in ('bwrap','rg'):
        subprocess.run([str(package/'codex-resources'/helper),'--version'],env=env,check=True,stdout=subprocess.DEVNULL,timeout=60)
    host=package/'codex-resources/codex-code-mode-host'
    full=(package/'bin/codex-app-server').is_file()
    if full:
        assert os.path.lexists(host),f'missing code-mode host: {host}'
    host_checked=os.path.lexists(host)
    if host_checked:
        subprocess.run([str(host),'--help'],env=env,check=True,stdout=subprocess.DEVNULL,timeout=60)
    if args.sandbox:
        assert 'ripgrep' in run('sandbox','--',str(package/'codex-resources/rg'),'--version')
print('Codex version, CLI, policy evaluation, direct catalog and helpers passed'
      + (', code-mode host passed' if host_checked else '')
      + '; no model requests made.')
