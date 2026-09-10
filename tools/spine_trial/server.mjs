// Local dashboard plus the upstream MCP endpoint. All assets stay in the trial workspace.
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import fs from 'node:fs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const config=JSON.parse(fs.readFileSync(path.join(root,'tools/spine_trial/toolchain.json'),'utf8'));
process.env.SPINE_MCP_ROOT=path.join(root,'artifacts/spine_trial');
process.env.SPINE_MCP_PORT=String(config.port);
process.env.SPINE_MCP_EDITOR_VERSION=config.data_version;
const source=path.join(root,config.motion_source);
const {createApp}=await import(pathToFileURL(path.join(source,'dist/server.js')).href);
const {app}=createApp();
const listener=app.listen(config.port,'127.0.0.1',()=>{
  console.log(JSON.stringify({name:'dungeon-draft-spine-trial',port:config.port,root:process.env.SPINE_MCP_ROOT,editor_export_available:false}));
});
listener.on('error',error=>{console.error(error.message);process.exitCode=1;});
