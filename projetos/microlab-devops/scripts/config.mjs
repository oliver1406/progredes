import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const file=path.join(root,'infra/.env');
const secretKeys=['POSTGRES_PASSWORD','STAGING_DB_PASSWORD','ZABBIX_DB_PASSWORD','GRAFANA_ADMIN_PASSWORD','GRAFANA_SECRET_KEY','DUPLICATI_UI_PASSWORD','DUPLICATI_ENCRYPTION_KEY'];
export function parseEnv(text){
  const values={};
  for(const line of text.split(/\r?\n/)){
    if(!line.trim()||line.trimStart().startsWith('#'))continue;
    const m=line.match(/^([A-Z][A-Z0-9_]*)=([^\r\n]*)$/);
    if(!m||Object.hasOwn(values,m[1]))throw Error('Formato inválido ou chave duplicada no arquivo de ambiente');
    // Valores literais, sem expansão Compose, aspas ou código shell.
    if(/[\s'"`$\\]/.test(m[2]))throw Error('Use valores literais sem espaços, aspas ou expansão');
    values[m[1]]=m[2];
  }
  return values;
}
function write(values){
  const temp=file+'.tmp-'+process.pid;
  fs.writeFileSync(temp,Object.entries(values).map(([k,v])=>`${k}=${v}`).join('\n')+'\n',{mode:0o600});
  fs.chmodSync(temp,0o600);fs.renameSync(temp,file);
}
export function validate(env){
  for(const key of ['HOST_UID','HOST_GID'])if(!/^\d+$/.test(env[key]||'')||Number(env[key])===0)throw Error(`${key} deve identificar usuário/grupo comum`);
  for(const name of secretKeys)if(!env[name]||env[name].length<24)throw Error(`Chave obrigatória fraca ou ausente: ${name}`);
  const ip=env.BIND_IP;
  if(ip!=='127.0.0.1')throw Error('Este perfil local exige BIND_IP=127.0.0.1; acesso remoto requer configuração própria');
  const url=new URL(env.GITEA_ROOT_URL);if(!['http:','https:'].includes(url.protocol)||url.username||url.password)throw Error('URL inválida');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
  try{
    const [cmd,key,value]=process.argv.slice(2);
    const env=parseEnv(fs.readFileSync(fs.existsSync(file)?file:path.join(root,'infra/.env.example'),'utf8'));
    if(cmd==='init'){
      if(key!=='127.0.0.1')throw Error('Este perfil local exige 127.0.0.1; revise a migração de configuração anterior');
      if(fs.existsSync(file)&&env.BIND_IP!==key)throw Error('Endereço existente diferente. Revise a mudança e use config.mjs set BIND_IP e GITEA_ROOT_URL explicitamente');
      env.BIND_IP=key;
      if(!fs.existsSync(file))env.GITEA_ROOT_URL=`http://${key}:3000/`;
      for(const name of secretKeys)if(!env[name])env[name]=crypto.randomBytes(32).toString('hex');
      validate(env);write(env);
      fs.mkdirSync(path.join(root,'state'),{recursive:true,mode:0o700});
      const release=path.join(root,'state/releases.env');
      if(!fs.existsSync(release))fs.writeFileSync(release,'STAGING_IMAGE=microlab-app:unreleased\nPROD_IMAGE=microlab-app:unreleased\n',{mode:0o600});
      console.log('CONFIG_INITIALIZED');
    }else if(cmd==='set'){
      if(!Object.hasOwn(env,key)||typeof value!=='string'||!value)throw Error('Chave/valor inválido');
      env[key]=value;parseEnv(Object.entries(env).map(([k,v])=>`${k}=${v}`).join('\n'));validate(env);write(env);console.log('CONFIG_UPDATED');
    }else if(cmd!=='check')throw Error('Uso: config.mjs init IP | check | set CHAVE VALOR');
    validate(env);
    console.log('CONFIG_VALID');
  }catch(e){console.error(e.message);process.exitCode=1;}
}
