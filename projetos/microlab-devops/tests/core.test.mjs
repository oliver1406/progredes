import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import http from 'node:http';
import {spawn,spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {parseEnv,validate} from '../scripts/config.mjs';
import {createClient} from '../scripts/zabbix-client.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
function fixture(){
  const base=process.env.MICROLAB_TEST_TMP_DIR||os.tmpdir();fs.mkdirSync(base,{recursive:true});
  const dir=fs.mkdtempSync(path.join(base,'microlab-test-'));
  fs.cpSync(path.join(root,'scripts'),path.join(dir,'scripts'),{recursive:true});
  fs.mkdirSync(path.join(dir,'infra'));
  fs.copyFileSync(path.join(root,'infra/.env.example'),path.join(dir,'infra/.env.example'));
  return dir;
}
function run(dir,...args){return spawnSync(process.execPath,[path.join(dir,'scripts/config.mjs'),...args],{encoding:'utf8'});}
test('parser rejeita chave duplicada e expansão em vez de interpretar código',()=>{
  assert.deepEqual(parseEnv('A=literal\n# comment\n'),{A:'literal'});
  for(const bad of ['A=x\nA=y','A=$(whoami)','A=`whoami`','export A=x'])assert.throws(()=>parseEnv(bad));
});
test('init gera segredos distintos e reexecução preserva bytes',()=>{
  const dir=fixture();try{
    assert.equal(run(dir,'init','127.0.0.1').status,0);
    const file=path.join(dir,'infra/.env');const before=fs.readFileSync(file,'utf8');
    const env=parseEnv(before);validate(env);
    assert.notEqual(env.POSTGRES_PASSWORD,env.STAGING_DB_PASSWORD);
    assert.equal(run(dir,'init','127.0.0.1').status,0);assert.equal(fs.readFileSync(file,'utf8'),before);
    assert.notEqual(run(dir,'init','100.64.1.2').status,0);assert.equal(fs.readFileSync(file,'utf8'),before);
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('set inválido não grava arquivo nem publica bind aberto',()=>{
  const dir=fixture();try{
    assert.equal(run(dir,'init','127.0.0.1').status,0);
    const file=path.join(dir,'infra/.env');const before=fs.readFileSync(file,'utf8');
    for(const [key,value]of [['BIND_IP','0.0.0.0'],['BIND_IP','8.8.8.8'],['BIND_IP','100.64.1.2'],['GITEA_ROOT_URL','bad-url'],['POSTGRES_PASSWORD','weak']]){
      assert.notEqual(run(dir,'set',key,value).status,0);assert.equal(fs.readFileSync(file,'utf8'),before);
    }
    assert.equal(run(dir,'set','GITEA_ROOT_URL','http://127.0.0.1:3000/').status,0);
    assert.equal(parseEnv(fs.readFileSync(file,'utf8')).BIND_IP,'127.0.0.1');
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
test('release-state mantém outro ambiente e rejeita imagem mutável sem gravar',()=>{
  const dir=fixture();try{
    assert.equal(run(dir,'init','127.0.0.1').status,0);
    const state=path.join(dir,'state');const file=path.join(state,'releases.env');
    const image='sha256:'+'a'.repeat(64);
    const cmd=(...args)=>spawnSync(process.execPath,[path.join(dir,'scripts/release-state.mjs'),state,'set',...args],{encoding:'utf8'});
    assert.equal(cmd('STAGING_IMAGE',image).status,0);let before=fs.readFileSync(file,'utf8');
    assert.equal(parseEnv(before).PROD_IMAGE,'microlab-app:unreleased');
    assert.notEqual(cmd('PROD_IMAGE','demo:latest').status,0);assert.equal(fs.readFileSync(file,'utf8'),before);
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
async function server(handler,fn){
  const s=http.createServer(handler);await new Promise(r=>s.listen(0,'127.0.0.1',r));
  try{await fn(`http://127.0.0.1:${s.address().port}/api_jsonrpc.php`);}finally{s.closeAllConnections();await new Promise(r=>s.close(r));}
}
test('cliente API rejeita HTTP, HTML, id errado, erro e result ausente/nulo',async()=>{
  const bad=[{code:503,body:'down'},{code:200,body:'<html>'},{json:{id:999,result:[]}}, {json:{error:{code:-1}}},{json:{}},{json:{result:null}}];
  await server(async(req,res)=>{
    let raw='';for await(const chunk of req)raw+=chunk;const input=JSON.parse(raw);const next=bad.shift();
    res.statusCode=next.code||200;res.end(next.body||JSON.stringify({jsonrpc:'2.0',id:input.id,...next.json}));
  },async url=>{const c=createClient(url);for(let i=0;i<6;i++)await assert.rejects(c.call('host.get',{}));});
});
for(const existing of [false,true])test(`bootstrap ${existing?'reexecutado':'novo'} respeita API e aceita amostra recente`,async()=>{
  const dir=fixture();assert.equal(run(dir,'init','127.0.0.1').status,0);const calls=[];let failure;
  try{
    await server(async(req,res)=>{
      let raw='';for await(const chunk of req)raw+=chunk;const input=JSON.parse(raw);calls.push(input.method);
      try{
        let result;const p=input.params;
        if(input.method==='apiinfo.version'){assert.equal(req.headers.authorization,undefined);result='7.0.99';}
        else{
          assert.equal(req.headers.authorization,'Bearer test-token');
          switch(input.method){
            case 'hostgroup.get':result=[{groupid:'1'}];break;
            case 'template.get':result=[{templateid:'10'}];break;
            case 'host.get':result=existing?[{hostid:p.filter.host[0]==='microlab-services'?'2':'1',tags:[{tag:'managed-by',value:'microlab'}],parentTemplates:[]}]:[];break;
            case 'host.create':result={hostids:[p.host==='microlab-services'?'2':'1']};break;
            case 'host.update':result={hostids:[p.hostid]};break;
            case 'item.get':result=p.output.includes('lastclock')?[{lastclock:String(Math.floor(Date.now()/1000)),lastvalue:'1'}]:(existing?[{itemid:'20'}]:[]);break;
            case 'item.update':assert.ok(!Object.hasOwn(p,'hostid'));result={itemids:['20']};break;
            case 'item.create':assert.equal(p.type,7);result={itemids:['20']};break;
            case 'trigger.get':result=existing?[{triggerid:'30'}]:[];break;
            case 'trigger.create':case 'trigger.update':result={triggerids:['30']};break;
            case 'httptest.get':result=existing?[{httptestid:'40',steps:[{httpstepid:'50',name:'health'}]}]:[];break;
            case 'httptest.update':assert.ok(!Object.hasOwn(p,'hostid'));assert.equal(p.steps[0].httpstepid,'50');result={httptestids:['40']};break;
            case 'httptest.create':assert.equal(p.steps[0].status_codes,'200');result={httptestids:['40']};break;
            default:throw Error('Método inesperado: '+input.method);
          }
        }
        res.end(JSON.stringify({jsonrpc:'2.0',id:input.id,result}));
      }catch(e){failure=e;res.statusCode=500;res.end('failed');}
    },async url=>{
      const child=spawn(process.execPath,[path.join(dir,'scripts/zabbix-bootstrap.mjs')],{env:{...process.env,ZBX_API_TOKEN:'test-token',ZBX_URL:url},stdio:['ignore','pipe','pipe']});
      let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
      const code=await new Promise(r=>child.on('exit',r));if(failure)throw failure;
      assert.equal(code,0,output);assert.match(output,/AGENT_DATA_RECEIVED/);assert.equal(calls[0],'apiinfo.version');
    });
  }finally{fs.rmSync(dir,{recursive:true,force:true});}
});
