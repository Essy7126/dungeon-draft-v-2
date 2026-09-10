const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../..'),out=path.join(root,'artifacts/spine_trial/passe_rive_walk_audit');
fs.mkdirSync(out,{recursive:true});
fs.copyFileSync(path.join(__dirname,'audit.html'),path.join(out,'review.html'));
fs.copyFileSync(path.join(root,'docs/design/achilles/passe_rive_walk_audit_2026-09-10.md'),path.join(out,'report.md'));
console.log(out);
