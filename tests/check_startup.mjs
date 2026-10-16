// Optional Node.js 22+ integration check. Run from the project root with Rscript on PATH.
// Override RRM_TEST_R with an Rscript-compatible executable if needed.
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
const dataMode=process.env.RRM_TEST_MODE||'operational';
const port=19000+Math.floor(Math.random()*1000);
const processR=spawn(process.env.RRM_TEST_R||'Rscript',['-e',`shiny::runApp('.',host='127.0.0.1',port=${port},launch.browser=FALSE)`],{cwd:process.cwd(),env:{...process.env,RRM_DATA_MODE:dataMode}});
let log='',socket;
processR.stderr.on('data',d=>{log+=d;});
try {
  for(let i=0;i<150;i++) {await new Promise(r=>setTimeout(r,100));if(log.includes('Listening on'))break;if(processR.exitCode!==null)throw Error(log);}
  const root=`http://127.0.0.1:${port}/`;
  const response=await fetch(root);assert.equal(response.status,200);
  const html=await response.text();assert(html.includes('id="coverage-coverage_map"'));
  const assets=[...html.matchAll(/(?:src|href)="([^"#]+)"/g)].map(m=>m[1]).filter(x=>!x.startsWith('http')&&!x.startsWith('data:'));
  const mapAssets=assets.filter(x=>/rrm-geography/.test(x));assert.equal(mapAssets.length,4,'Map binding/dependencies must load before the first Shiny response');
  for(const asset of new Set(assets))assert.equal((await fetch(new URL(asset,root))).status,200,asset);
  const values={},errors={};
  socket=new WebSocket(`ws://127.0.0.1:${port}/websocket`);
  socket.onmessage=e=>{const m=JSON.parse(e.data);Object.assign(values,m.values||{});Object.assign(errors,m.errors||{});};
  await new Promise((resolve,reject)=>{socket.onopen=resolve;socket.onerror=reject;});
  const input={page:'activity','alerts-alert_id':'DEMO-001','coverage-as_of':'2026-10-16','coverage-area':'All','coverage-partner':'All','coverage-role':'All','coverage-map_province':'All','coverage-map_district':'All','coverage-map_post':'All','household-source':'operational','household-population':'All','household-profile':'all_households','activity_excel-show_all':true,'activity_excel-map_scope':'all'};
  if(dataMode==='demo') input['rna-assessment_id']='DEMO-RNA-01';
  for(const id of ['alerts-alert_map','alerts-endpoint_review','coverage-map_slot','coverage-coverage_map','coverage-table','household-summary','rna-table','activity_excel-outputs','activity_excel-location_map','activity_excel-location_review'])input[`.clientdata_output_${id}_hidden`]=false;
  // No assessment_id exists in production. The RNA table must still send a real empty widget.
  socket.send(JSON.stringify({method:'init',data:input}));
  for(let i=0;i<150;i++){await new Promise(r=>setTimeout(r,100));if(['alerts-alert_map','alerts-endpoint_review','coverage-coverage_map','coverage-table','household-summary','rna-table','activity_excel-outputs','activity_excel-location_map','activity_excel-location_review'].every(id=>values[id]!==undefined))break;}
  for(const id of ['coverage-table','household-summary','rna-table','activity_excel-outputs']) {
    let value=values[id];assert.notEqual(value,undefined,id+' not received');
    if(typeof value==='string')value=JSON.parse(value);
    assert(value&&value.x, id+' must not send x:null to hidden DT outputs');
  }
  assert.equal(values['alerts-alert_map'].kind,'alert_routes');
  assert.equal(values['alerts-alert_map'].markers.features.length,dataMode==='demo'?3:0,'Alert points must follow the selected data mode');
  assert.equal(values['alerts-alert_map'].connections.features.length,dataMode==='demo'?2:0);
  assert.equal(values['coverage-coverage_map'].districts.features.length,19);
  assert.equal(values['coverage-coverage_map'].posts.features.length,64);
  assert.equal(values['activity_excel-location_map'].markers.features.length,7);
  assert(values['activity_excel-location_map'].markers.features.every(f=>f.properties.validated_records===0));
  assert.deepEqual(errors,{});
  console.log('PASS: HTTP assets, initial map binding, 19 districts, 64 posts non-null empty table payloads, and seven reported intervention points over Shiny WebSocket.');
}finally{if(socket)socket.close();processR.kill('SIGTERM');}
