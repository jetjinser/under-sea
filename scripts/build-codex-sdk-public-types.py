import argparse, json, shutil, subprocess
from pathlib import Path
parser=argparse.ArgumentParser(description='Compile the Codex SDK public MCP/Zod declaration closure from source')
parser.add_argument('sdk_work',type=Path)
parser.add_argument('mcp_source',type=Path)
parser.add_argument('work',type=Path)
parser.add_argument('--node',default='node')
parser.add_argument('--install-sdk',type=Path)
args=parser.parse_args()
base=args.work.resolve()
base.mkdir()
compiler=(args.sdk_work/'node_modules/typescript/bin/tsc').resolve()
node=args.node
zod=base/'zod'
shutil.copytree((args.sdk_work/'node_modules/zod/src').resolve(),zod/'src')
(zod/'node_modules/@types').mkdir(parents=True)
(zod/'node_modules/@types/node').symlink_to((args.sdk_work/'node_modules/@types/node').resolve(),target_is_directory=True)
(zod/'node_modules/undici-types').symlink_to((args.sdk_work/'node_modules/undici-types').resolve(),target_is_directory=True)
zconfig={'compilerOptions':{'target':'ES2022','module':'NodeNext','moduleResolution':'NodeNext','strict':True,'declaration':True,'declarationMap':True,'emitDeclarationOnly':True,'rootDir':'src','outDir':'types','types':['node'],'skipLibCheck':False},'files':['src/v4/index.ts']}
(zod/'package.json').write_text('{"type":"module"}')
(zod/'tsconfig.json').write_text(json.dumps(zconfig))
subprocess.run([node,str(compiler),'-p',str(zod/'tsconfig.json')],check=True)
mcp=base/'mcp'
shutil.copytree(args.mcp_source/'src',mcp/'src')
(mcp/'node_modules').mkdir()
(mcp/'node_modules/zod').symlink_to(zod,target_is_directory=True)
(zod/'package.json').write_text(json.dumps({'name':'zod','version':'3.25.76','type':'module','exports':{'./v4':{'types':'./types/v4/index.d.ts'}}}))
config=json.loads((args.mcp_source/'tsconfig.json').read_text())
config['compilerOptions'].update(types=[],rootDir='src',outDir='types',emitDeclarationOnly=True,skipLibCheck=False)
config['compilerOptions'].pop('paths',None)
config.pop('include')
config['files']=['src/types.ts','src/server/auth/types.ts']
(mcp/'tsconfig.json').write_text(json.dumps(config))
subprocess.run([node,str(compiler),'-p',str(mcp/'tsconfig.json')],check=True)
print('Compiled Zod v4 and MCP public type closure from source')
if args.install_sdk:
    modules=args.install_sdk/'node_modules'
    for name,version,built,original,exports in (
        ('zod','3.25.76',zod,args.sdk_work/'node_modules/zod',
         {'./v4':{'types':'./types/v4/index.d.ts'}}),
        ('@modelcontextprotocol/sdk','1.26.0',mcp,args.mcp_source,
         {'./types.js':{'types':'./types/types.d.ts'}}),
    ):
        target=modules/name
        target.mkdir(parents=True,exist_ok=False)
        shutil.copytree(built/'types',target/'types')
        shutil.copytree(built/'src',target/'src')
        license_file=original/'LICENSE'
        if not license_file.is_file():
            raise ValueError('Missing declaration-source license: '+name)
        shutil.copy2(license_file,target/'LICENSE')
        # These private packages expose declarations only. They deliberately
        # have no runtime export: this does not install a partial MCP runtime.
        metadata={'name':name,'version':version,'private':True,'type':'module',
                  'description':'Source-built public declarations for the Codex SDK',
                  'exports':exports}
        (target/'package.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print('Installed private source-built declaration closure; no MCP runtime export')
    # Compile a consumer against the installed package, not the build-time
    # node_modules. This catches missing public types and ESM export paths.
    consumer=base/'installed-consumer'
    (consumer/'node_modules/@openai').mkdir(parents=True)
    (consumer/'node_modules/@openai/codex-sdk').symlink_to(
        args.install_sdk.resolve(),target_is_directory=True)
    (consumer/'package.json').write_text('{"type":"module"}\n')
    (consumer/'index.ts').write_text(
        "import { Codex, type ThreadItem, type ThreadOptions } from '@openai/codex-sdk';\n"
        "export type PublicTypes = { options: ThreadOptions; item: ThreadItem; client: Codex };\n")
    (consumer/'tsconfig.json').write_text(json.dumps({
        'compilerOptions':{'target':'ES2022','module':'NodeNext',
                           'moduleResolution':'NodeNext','strict':True,
                           'noEmit':True,'skipLibCheck':False,'types':[]},
        'files':['index.ts']}))
    subprocess.run([node,str(compiler),'-p',str(consumer/'tsconfig.json')],check=True)
    print('Installed public declarations compile for a strict NodeNext consumer')
