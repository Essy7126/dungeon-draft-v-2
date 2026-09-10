import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const settings=JSON.parse(fs.readFileSync(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const modules=path.join(root,settings.motion_source,'node_modules/@modelcontextprotocol/sdk/dist/esm/client');
const {Client}=await import(pathToFileURL(path.join(modules,'index.js')).href);
const {StreamableHTTPClientTransport}=await import(pathToFileURL(path.join(modules,'streamableHttp.js')).href);
const client=new Client({name:'dungeon-draft-spine-command',version:'1'});
try {
  const name=process.argv[2];
  if(!settings.enabled_tools.includes(name))throw new Error('Tool unavailable in this trial configuration.');
  await client.connect(new StreamableHTTPClientTransport(new URL(`http://127.0.0.1:${settings.port}/mcp`)));
  const result=await client.callTool({name,arguments:JSON.parse(process.argv[3]??'{}')},undefined,{timeout:120000});
  for(const item of result.content??[])if(item.type==='text')console.log(item.text);
  if(result.isError)process.exitCode=1;
} finally {await client.close();}
