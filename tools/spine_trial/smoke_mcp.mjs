import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const settings=JSON.parse(fs.readFileSync(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
const modules=path.join(root,settings.motion_source,'node_modules');
const {Client}=await import(pathToFileURL(path.join(modules,'@modelcontextprotocol/sdk/dist/esm/client/index.js')).href);
const {StreamableHTTPClientTransport}=await import(pathToFileURL(path.join(modules,'@modelcontextprotocol/sdk/dist/esm/client/streamableHttp.js')).href);
const client=new Client({name:'dungeon-draft-spine-smoke',version:'1'});
const trialRoot=path.join(root,'artifacts/spine_trial');
const output=path.join(root,'artifacts/dev',`spine-mcp-${Date.now()}`);
fs.mkdirSync(output,{recursive:true});
const checks=[];
const source=path.join(trialRoot,'examples/spineboy/spineboy-pro.json');
const original=fs.readFileSync(source);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
fs.writeFileSync(path.join(output,'context.json'),JSON.stringify({git_head:execFileSync('git',['rev-parse','HEAD'],{cwd:root,encoding:'utf8'}).trim(),settings},null,2));
async function tool(name,args={},expectError=false){
  const result=await client.callTool({name,arguments:args},undefined,{timeout:120000});
  fs.writeFileSync(path.join(output,`${checks.length}-${name}.json`),JSON.stringify(result,null,2));
  if(Boolean(result.isError)!==expectError)throw new Error(`${name}: ${JSON.stringify(result).slice(0,1800)}`);
  checks.push({name,passed:true,expected_error:expectError});
  if(expectError)return result;
  return JSON.parse(result.content.find(item=>item.type==='text').text);
}
try {
  await client.connect(new StreamableHTTPClientTransport(new URL(`http://127.0.0.1:${settings.port}/mcp`)));
  const catalog=await client.listTools();
  fs.writeFileSync(path.join(output,'tools.json'),JSON.stringify(catalog,null,2));
  for(const name of settings.enabled_tools)if(!catalog.tools.some(tool=>tool.name===name))throw new Error(`Missing ${name}`);
  await tool('spine_status');
  await tool('skeleton_inspect',{path:'examples/spineboy/spineboy-pro.json'});
  const copies=path.join(trialRoot,'checks');fs.mkdirSync(copies,{recursive:true});
  const candidate=path.join(copies,'spineboy-check.json');fs.writeFileSync(candidate,original);
  for(const [from,to] of [['spineboy.atlas','spineboy-check.atlas'],['spineboy.png','spineboy.png']])fs.copyFileSync(path.join(trialRoot,'examples/spineboy',from),path.join(copies,to));
  await tool('skeleton_inspect',{path:'checks/spineboy-check.json'});
  await tool('keys_set',{path:'checks/spineboy-check.json',animation:'connector_check',keys:[{bone:'root',property:'translate',time:0,value:{x:0,y:0},easing:'easeInOut'},{bone:'root',property:'translate',time:0.5,value:{x:0,y:50},easing:'easeInOut'},{bone:'root',property:'translate',time:1,value:{x:0,y:0}}]});
  const data=JSON.parse(fs.readFileSync(candidate));
  if(data.animations.connector_check.bones.root.translate[1].y!==50)throw new Error('Key not persisted');
  await tool('skeleton_lint',{path:'checks/spineboy-check.json'});
  await tool('skeleton_inspect',{path:'../outside.json'},true);
  await tool('preview_url',{jsonPath:'checks/spineboy-check.json',animation:'connector_check'});
  const preview=await tool('preview_gif',{jsonPath:'checks/spineboy-check.json',animation:'connector_check',fps:8,size:420});
  if(!fs.existsSync(preview.gif)||preview.frames!==8)throw new Error('GIF missing or incomplete');
  if(hash(fs.readFileSync(source))!==hash(original))throw new Error('Official original changed');
  const summary={passed:true,checks,preview,output};fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2));console.log(JSON.stringify(summary));
} catch(error){const summary={passed:false,checks,error:error.message,output};fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2));console.error(JSON.stringify(summary));process.exitCode=1;}
finally{await client.close();}
