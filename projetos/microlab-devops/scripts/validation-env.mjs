// Somente dados sintéticos para validar Compose; não é configuração de implantação.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseEnv} from './config.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const out=process.argv[2];if(!out)throw Error('Informe arquivo temporário de saída');
const env=parseEnv(fs.readFileSync(path.join(root,'infra/.env.example'),'utf8'));
for(const key of Object.keys(env))if(key.endsWith('PASSWORD')||key.endsWith('KEY'))env[key]='synthetic-validation-value-0123456789';
fs.writeFileSync(out,Object.entries(env).map(([k,v])=>`${k}=${v}`).join('\n')+'\n',{mode:0o600});
console.log('SYNTHETIC_ENV_CREATED');
