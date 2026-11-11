import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseEnv} from './config.mjs';
import {createClient} from './zabbix-client.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const env=parseEnv(fs.readFileSync(path.join(root,'infra/.env'),'utf8'));
const url=process.env.ZBX_URL||(process.env.MICROLAB_CONTAINER_MODE==='1'?'http://zabbix-web:8080/api_jsonrpc.php':`http://${env.BIND_IP}:8080/api_jsonrpc.php`);
const client=createClient(url);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let loggedIn=false;
async function main(){
  const version=await client.call('apiinfo.version',{});
  if(!/^7\.0\./.test(version))throw Error('Este bootstrap requer API Zabbix 7.0');
  if(process.env.ZBX_API_TOKEN)client.setToken(process.env.ZBX_API_TOKEN);
  if(!process.env.ZBX_API_TOKEN){
    const token=await client.call('user.login',{username:process.env.ZBX_USER||'Admin',password:process.env.ZBX_PASSWORD||''});
    if(typeof token!=='string'||!token)throw Error('Login inválido');client.setToken(token);loggedIn=true;
  }
  let groups=await client.call('hostgroup.get',{output:['groupid'],filter:{name:['Microlab']}});
  const groupid=groups[0]?.groupid||(await client.call('hostgroup.create',{name:'Microlab'})).groupids[0];
  const templates=await client.call('template.get',{output:['templateid'],filter:{host:['Linux by Zabbix agent active']}});
  if(templates.length!==1)throw Error('Template Linux ativo não encontrado de forma única');
  const hostname=process.env.ZBX_HOSTNAME||'microlab-docker';
  if(!/^[a-zA-Z0-9_.-]+$/.test(hostname))throw Error('Hostname inválido');
  async function managedHost(host,templateid){
    const found=await client.call('host.get',{output:['hostid'],filter:{host:[host]},selectTags:'extend',selectParentTemplates:['templateid','host']});
    if(found.length>1)throw Error('Host duplicado');
    if(found[0]){
      const h=found[0];
      if(!h.tags.some(t=>t.tag==='managed-by'&&t.value==='microlab'))throw Error(`Host ${host} já existe fora deste bootstrap; migração manual necessária`);
      if(h.parentTemplates.some(t=>t.host==='Linux by Zabbix agent'))throw Error('Template passivo presente: migração explícita necessária, sem limpeza automática');
      const existing=h.parentTemplates.map(t=>({templateid:t.templateid}));
      if(templateid&&!existing.some(t=>t.templateid===templateid))existing.push({templateid});
      await client.call('host.update',{hostid:h.hostid,status:0,templates:existing});return h.hostid;
    }
    return (await client.call('host.create',{host,name:host,status:0,groups:[{groupid}],tags:[{tag:'managed-by',value:'microlab'}],...(templateid?{templates:[{templateid}]}:{})})).hostids[0];
  }
  const hostid=await managedHost(hostname,templates[0].templateid);
  const itemKey='microlab.backup.age';
  const items=await client.call('item.get',{output:['itemid'],hostids:[hostid],filter:{key_:[itemKey]}});
  const item={hostid,name:'Microlab: idade do último backup de banco',key_:itemKey,type:7,value_type:3,units:'s',delay:'1m',status:0};
  if(items[0]){const {hostid:unused,...update}=item;await client.call('item.update',{...update,itemid:items[0].itemid});}else await client.call('item.create',item);
  async function trigger(hostId,description,expression){
    const found=await client.call('trigger.get',{output:['triggerid'],hostids:[hostId],filter:{description:[description]}});
    const data={description,expression,priority:4,status:0};
    if(found[0])await client.call('trigger.update',{...data,triggerid:found[0].triggerid});else await client.call('trigger.create',data);
  }
  await trigger(hostid,'Microlab: backup ausente ou atrasado',`last(/${hostname}/${itemKey})>90000 or nodata(/${hostname}/${itemKey},5m)=1`);
  const servicesId=await managedHost('microlab-services');
  for(const [name,target] of [['microlab-prod','app-prod'],['microlab-staging','app-staging']]){
    const found=await client.call('httptest.get',{output:['httptestid'],selectSteps:['httpstepid','name'],hostids:[servicesId],filter:{name:[name]}});
    const data={name,hostid:servicesId,delay:'1m',retries:1,status:0,steps:[{name:'health',no:1,url:`http://${target}:8080/health`,required:'ok',status_codes:'200',timeout:'5s'}]};
    if(found[0]){
      const {hostid:unused,...update}=data;
      const previousStep=found[0].steps.find(s=>s.name==='health');
      if(previousStep)update.steps[0].httpstepid=previousStep.httpstepid;
      await client.call('httptest.update',{...update,httptestid:found[0].httptestid});
    }else await client.call('httptest.create',data);
    await trigger(servicesId,`Microlab: indisponibilidade ${name}`,`last(/microlab-services/web.test.fail[${name}])<>0 or nodata(/microlab-services/web.test.fail[${name}],5m)=1`);
  }
  console.log('MONITORING_CONFIGURED: aguardando amostra real do agente ativo');
  const deadline=Date.now()+300000;
  while(Date.now()<deadline){
    const samples=await client.call('item.get',{output:['key_','lastclock','lastvalue'],hostids:[hostid],filter:{key_:[itemKey]}});
    if(samples.some(i=>Number(i.lastclock)>Date.now()/1000-180)){
      console.log('AGENT_DATA_RECEIVED: verifique o valor e os problemas; alertas externos ainda precisam ser configurados');return;
    }
    await sleep(5000);
  }
  throw Error('Configuração aplicada, mas o agente não entregou dado recente em cinco minutos');
}
try{await main();}catch(e){console.error(e.message);process.exitCode=1;}finally{if(loggedIn){try{await client.call('user.logout',[]);}catch{console.error('Sessão não encerrada; verificar expiração no Zabbix');process.exitCode=1;}}}
