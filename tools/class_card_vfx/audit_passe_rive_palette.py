"""Numerical audit of the continuous runtime transform (not a pixel-render test)."""
from pathlib import Path
import argparse,json
import numpy as np

GAME=Path(__file__).resolve().parents[2]


def transform(rgb,groups):
    c=np.asarray(rgb,float)/255;gain=np.full(3,.025);weight=.025
    for group in groups.values():
        center=np.asarray(group['source_rgb'])/255
        target=np.asarray(group['result_rgb'])/255
        peak=max(c);cp=max(center)
        chroma=c/max(peak,.025)-center/max(cp,.025)
        value=(peak-cp)/(.06+cp*.22)
        w=np.exp(-.5*(sum(chroma*chroma)/.0144+value*value))
        gain+=w*target/center;weight+=w
    return np.clip(c*gain/weight,0,1)*255


def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
    source=json.loads((GAME/'art/source/passe_rive_s23/palette_audit.json').read_text())
    registration=json.loads((GAME/'art/source/passe_rive_s23/registration_audit.json').read_text())
    rows=[]
    for key in registration['entries']:
        groups=source['measurements'][key]
        for group,values in groups.items():
            before=np.asarray(values['source_rgb']);target=np.asarray(values['target_rgb'])
            after=transform(before,groups)
            rows.append({'clip':key,'material':group,'before_rgb_distance':float(np.linalg.norm(before-target)),
                         'after_rgb_distance':float(np.linalg.norm(after-target)),'output_rgb':list(after)})
    before=float(np.mean([r['before_rgb_distance'] for r in rows]));after=float(np.mean([r['after_rgb_distance'] for r in rows]))
    report={'method':'Mean Euclidean distance in 8-bit RGB between material medians and canonical idle_SE; evaluated with runtime shader equation; not anatomical or temporal validation.',
            'samples':len(rows),'before_mean_rgb_distance':before,'after_mean_rgb_distance':after,
            'reduction_percent':100*(1-after/before),'rows':rows}
    text=json.dumps(report,indent=2);path=GAME/'art/source/passe_rive_s23/palette_metrics.json'
    if args.check:assert path.read_text()==text
    else:path.write_text(text)
    print(json.dumps({k:v for k,v in report.items() if k!='rows'}))
    assert after<before*.4, 'Material color harmonization regressed'

if __name__=='__main__':main()
