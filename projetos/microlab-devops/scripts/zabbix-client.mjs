export function createClient(url, token=''){
  let id=0;
  return {
    setToken(value){token=value;},
    async call(method,params){
      const requestId=++id;
      const headers={'Content-Type':'application/json-rpc'};
      if(token)headers.Authorization=`Bearer ${token}`;
      const r=await fetch(url,{method:'POST',headers,body:JSON.stringify({jsonrpc:'2.0',method,params,id:requestId}),signal:AbortSignal.timeout(10000)});
      if(!r.ok)throw Error(`API HTTP ${r.status}: ${method}`);
      let body;try{body=await r.json();}catch{throw Error(`API JSON inválido: ${method}`);}
      if(body.jsonrpc!=='2.0'||body.id!==requestId||body.error||!Object.hasOwn(body,'result')||body.result===null)throw Error(`API resposta inválida/erro: ${method}`);
      return body.result;
    }
  };
}
