import fs from 'node:fs';
import path from 'node:path';
import {parseEnv} from './config.mjs';
const [dir,cmd,key,value]=process.argv.slice(2);
if(cmd!=='set'||!['STAGING_IMAGE','PROD_IMAGE'].includes(key)||!/^sha256:[a-f0-9]{64}$|^microlab-app:unreleased$/.test(value||''))throw Error('Alteração de release inválida');
const file=path.join(dir,'releases.env');const env=parseEnv(fs.readFileSync(file,'utf8'));env[key]=value;
const tmp=file+'.tmp-'+process.pid;
fs.writeFileSync(tmp,Object.entries(env).map(([k,v])=>`${k}=${v}`).join('\n')+'\n',{mode:0o600});fs.renameSync(tmp,file);
