import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {parseEnv} from './config.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const env=parseEnv(fs.readFileSync(path.join(root,'infra/.env'),'utf8'));
if(!env.ZABBIX_GRAFANA_USER||!env.ZABBIX_GRAFANA_PASSWORD)throw Error('Configure primeiro usuário dedicado de leitura e sua senha no .env');
const base=process.env.MICROLAB_CONTAINER_MODE==='1'?'http://grafana:3000':`http://${env.BIND_IP}:3001`;
const headers={Authorization:'Basic '+Buffer.from('admin:'+env.GRAFANA_ADMIN_PASSWORD).toString('base64'),'Content-Type':'application/json'};
async function req(method,url,body){const r=await fetch(base+url,{method,headers,body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(15000)});if(!r.ok)throw Error('Grafana HTTP '+r.status);return r.json();}
const uid='microlab-zabbix';
const data={uid,name:'Zabbix Microlab',type:'alexanderzobnin-zabbix-datasource',access:'proxy',url:'http://zabbix-web:8080/api_jsonrpc.php',isDefault:true,jsonData:{authType:'userLogin',username:env.ZABBIX_GRAFANA_USER,trends:true},secureJsonData:{password:env.ZABBIX_GRAFANA_PASSWORD}};
const all=await req('GET','/api/datasources');
if(all.some(d=>d.uid===uid))await req('PUT','/api/datasources/uid/'+uid,data);else await req('POST','/api/datasources',data);
const health=await req('GET','/api/datasources/uid/'+uid+'/health');
if(health.status!=='OK')throw Error('Datasource criado, mas teste de conexão falhou');
console.log('GRAFANA_DATASOURCE_HEALTHY: validar consultas e criar os painéis de métricas no roteiro de aceite');
