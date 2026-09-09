// Isolated editor/runtime contract test; never starts or stops the user's editor.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, execFileSync } from 'node:child_process';
import { createInterface } from 'node:readline';
import { randomUUID } from 'node:crypto';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const godot=process.argv[2];
if (!godot || !fs.existsSync(godot)) throw new Error('Pass the Godot console executable.');
const output=path.join(root, 'artifacts/dev', `workbench-${randomUUID()}`);
const project=path.join(output, 'project');
fs.mkdirSync(project,{recursive:true});
fs.cpSync(path.join(root,'addons/godot_ai_workbench'),path.join(project,'addons/godot_ai_workbench'),{recursive:true});
const port=18765;
fs.writeFileSync(path.join(project,'project.godot'),`config_version=5
[application]
config/name="Dev Workbench QA"
run/main_scene="res://probe.tscn"
[display]
window/size/viewport_width=640
window/size/viewport_height=360
[rendering]
renderer/rendering_method="gl_compatibility"
[autoload]
GawWorkbenchRuntimeProbe="*res://addons/godot_ai_workbench/runtime/workbench_runtime_probe.gd"
[editor_plugins]
enabled=PackedStringArray("res://addons/godot_ai_workbench/plugin.cfg")
[godot_ai_workbench]
auto_connect=true
profile="full_control"
port=${port}
`);
fs.writeFileSync(path.join(project,'probe.gd'),'extends Control\n@export var health: int = 75\nfunc _ready() -> void:\n\tprint("PROBE_DEBUGGER_ACTIVE=", EngineDebugger.is_active(), " PROBE_PRESENT=", get_node_or_null("/root/GawWorkbenchRuntimeProbe") != null)\n');
fs.writeFileSync(path.join(project,'probe.tscn'),`[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://probe.gd" id="1"]
[node name="Probe" type="Control"]
layout_mode=3
anchors_preset=15
anchor_right=1.0
anchor_bottom=1.0
script=ExtResource("1")
[node name="Label" type="Label" parent="."]
offset_left=40.0
offset_top=40.0
offset_right=600.0
offset_bottom=100.0
text="Workbench: runtime inspection and capture"
`);
let sequence=0;
const pending=new Map();
const checks=[];
const delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
const server=spawn(path.join(root,'artifacts/dev-tools/gaw.exe'),['--tool-mode','lite','--bridge-port',String(port),'--log-file',path.join(output,'bridge.log')],{cwd:root,windowsHide:true,stdio:['pipe','pipe','pipe']});
server.stderr.pipe(fs.createWriteStream(path.join(output,'server.stderr.log')));
const lines=createInterface({input:server.stdout});
lines.on('line',line=>{
  fs.appendFileSync(path.join(output,'rpc.jsonl'),line+'\n');
  let message;
  try {message=JSON.parse(line);} catch {return;}
  const request=pending.get(message.id);
  if(request){clearTimeout(request.timer);pending.delete(message.id);message.error?request.reject(new Error(JSON.stringify(message.error))):request.resolve(message.result);}
});
server.on('error',error=>{for(const request of pending.values()){clearTimeout(request.timer);request.reject(error);}pending.clear();});
function rpc(method,params={}){
  return new Promise((resolve,reject)=>{
    const id=++sequence;
    const timer=setTimeout(()=>{pending.delete(id);reject(new Error(`RPC timeout: ${method}`));},20000);
    pending.set(id,{resolve,reject,timer});
    server.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method,params})+'\n');
  });
}
let editor;
let catalog=[];
async function tool(name,args={},expectError=false){
  const descriptor=catalog.find(item=>item.name===name);
  if(!descriptor) throw new Error(`Tool unavailable in lite mode: ${name}`);
  const properties=descriptor.inputSchema?.properties??{};
  const defaults={project,status_url:`http://127.0.0.1:${port}/status`,control_url:`http://127.0.0.1:${port}/control`};
  const result=await rpc('tools/call',{name,arguments:{...Object.fromEntries(Object.entries(defaults).filter(([key])=>key in properties)),...args}});
  if(Boolean(result.isError)!==expectError) throw new Error(`Unexpected ${name} result: ${JSON.stringify(result).slice(0,1400)}`);
  return result;
}
function stopOwned(child){
  if(!child?.pid || child.exitCode!==null) return;
  try {execFileSync('taskkill.exe',['/PID',String(child.pid),'/T','/F'],{windowsHide:true,stdio:'ignore'});} catch {child.kill();}
}
try {
  await rpc('initialize',{protocolVersion:'2024-11-05',capabilities:{},clientInfo:{name:'dungeon-draft-workbench-smoke',version:'1'}});
  server.stdin.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/initialized'})+'\n');
  catalog=(await rpc('tools/list')).tools;
  fs.writeFileSync(path.join(output,'catalog.json'),JSON.stringify(catalog,null,2));
  const configured=JSON.parse(fs.readFileSync(path.join(root,'tools/dev/workbench-tools.json'),'utf8'));
  for(const name of configured){if(!catalog.some(tool=>tool.name===name))throw new Error(`Configured tool is missing: ${name}`);}
  checks.push({check:'mcp_initialize',passed:true,tool_count:catalog.length});
  const env={...process.env,APPDATA:path.join(output,'appdata'),LOCALAPPDATA:path.join(output,'localappdata')};
  fs.mkdirSync(env.APPDATA,{recursive:true});fs.mkdirSync(env.LOCALAPPDATA,{recursive:true});
  editor=spawn(godot,['--editor','--path',project,'--debug-server','tcp://127.0.0.1:16007','--lsp-port','16005','--rendering-method','gl_compatibility','--audio-driver','Dummy','--position','-3000,-3000','--log-file',path.join(output,'editor.engine.log')],{cwd:project,env,windowsHide:true,stdio:['ignore','pipe','pipe']});
  editor.stdout.pipe(fs.createWriteStream(path.join(output,'editor.stdout.log')));
  editor.stderr.pipe(fs.createWriteStream(path.join(output,'editor.stderr.log')));
  let connected=false;
  for(let attempt=0;attempt<50;attempt++){
    await delay(500);
    const response=await fetch(`http://127.0.0.1:${port}/status`);
    const status=await response.json();
    if(status.state?.handshake_complete){connected=true;break;}
    if(editor.exitCode!==null) throw new Error(`Editor exited: ${editor.exitCode}`);
  }
  if(!connected) throw new Error('Editor bridge did not connect.');
  checks.push({check:'editor_handshake',passed:true});
  const state=await tool('live.editor_state');
  fs.writeFileSync(path.join(output,'editor-state.json'),JSON.stringify(state,null,2));
  checks.push({check:'editor_inspection',passed:true});
  await tool('runtime.play_scene',{scene_path:'res://probe.tscn'});
  await delay(4000);
  const runtime=await tool('runtime.state',{node_path:'/root/Probe',properties:['health'],timeout_msec:5000});
  fs.writeFileSync(path.join(output,'runtime-state.json'),JSON.stringify(runtime,null,2));
  if(runtime.structuredContent?.values?.health!==75) throw new Error('Expected runtime health was not observed.');
  checks.push({check:'runtime_state',passed:true});
  const screenshot=await tool('runtime.screenshot');
  fs.writeFileSync(path.join(output,'screenshot.json'),JSON.stringify(screenshot,null,2));
  if(!fs.existsSync(screenshot.structuredContent?.absolute_path??'') || screenshot.structuredContent.width!==640 || screenshot.structuredContent.height!==360) throw new Error('Runtime screenshot is missing or has unexpected dimensions.');
  checks.push({check:'runtime_screenshot',passed:true});
  await tool('runtime.inspect_node',{node_path:'/root/MissingNode'},true);
  checks.push({check:'missing_node_is_error',passed:true});
  await tool('runtime.stop_scene');
  checks.push({check:'runtime_stop',passed:true});
  const diagnostics=await tool('live.debug_output',{limit:20});
  fs.writeFileSync(path.join(output,'diagnostics.json'),JSON.stringify(diagnostics,null,2));
  stopOwned(editor);editor=null;
  await delay(700);
  const disconnected=await (await fetch(`http://127.0.0.1:${port}/status`)).json();
  if(disconnected.state?.connected) throw new Error('Bridge still reports the terminated test editor as connected.');
  checks.push({check:'disconnect',passed:true});
  const summary={passed:true,checks,output};
  fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2));
  console.log(JSON.stringify(summary));
} catch(error) {
  for(const name of ['live.debug_output','live.debug_sessions']){
    try{const details=await tool(name);fs.writeFileSync(path.join(output,name+'.json'),JSON.stringify(details,null,2));}catch{}
  }
  const summary={passed:false,checks,error:error.message,output};
  fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2));
  console.error(JSON.stringify(summary));process.exitCode=1;
} finally {
  stopOwned(editor);stopOwned(server);lines.close();
  for(const request of pending.values()) clearTimeout(request.timer);
}
