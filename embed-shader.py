#!/usr/env/bin python3

SHADERS = {
    'fshader_glsl': 'gen/fshader-debug.glsl',
}

for defname, filename in SHADERS.items():
    print(f'const char * {defname} = "\\')
    with open(filename, 'r') as f:
        source = f.read().strip()
    source = source.replace('\n', '\\n\\\n')
    print(source + '";')
