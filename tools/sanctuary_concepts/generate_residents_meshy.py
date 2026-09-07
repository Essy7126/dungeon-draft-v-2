"""Two 2D resident sprites for the approved sanctuary, through Meshy."""
import getpass, json, os
from pathlib import Path
from generate_meshy_concepts import ROOT, meshy

def main():
    os.chdir(ROOT)
    os.environ['MESHY_API_KEY'] = getpass.getpass('Meshy session key (hidden): ').strip()
    try:
        prompt = '''Create a production 2D isometric game character sprite atlas: EXACTLY TWO complete isolated standing adult Greek fantasy residents, side by side with large space between them. True transparent background, no floor, no backdrop, no scene, no shadows. High angle isometric game camera looking DOWN at both characters, visible tops of heads and shoulders, full body from head to sandals, feet at the same baseline, three quarter facing toward lower right. Left half: a stocky elderly male Greek merchant with a short grey beard, warm terracotta tunic, muted ochre draped cloak, leather belt with small purse, carrying a small bronze weighing scale at waist level, friendly clever face. Right half: a tall adult Greek oracle priestess in a desaturated teal-blue draped robe and pale ivory veil, restrained bronze ornaments, holding a small amber votive lamp at waist, serene face. Beautiful richly textured hand-painted gouache and tempera illustration, mineral pigments, visible fine woven cloth texture, worn bronze patina, nuanced painted skin, crisp elegant colored outlines. Match a premium mythological Greek underworld RPG sanctuary with violet shadows and soft amber highlights. Readable bold silhouettes at small game size, each figure occupies about one third of total image width and 80 percent of height. The two figures must never touch or overlap. No text, labels, UI, borders, weapons, extra figures, scenery or photorealism. Every body extremity fully in frame with clear transparent margin. Keep bottom feet completely visible.'''
        payload={'ai_model':'gpt-image-2','aspect_ratio':'3:2','alpha_thumbnail':True,'prompt':prompt}
        task_id=meshy.create_task('/openapi/v1/text-to-image',payload)
        d=Path(meshy.get_project_dir(task_id,'sanctuary_residents'))
        (d/'payload.json').write_text(json.dumps(payload,indent=2),encoding='utf-8')
        meshy.record_task(str(d),task_id,'text-to-image','created',prompt='Sanctuary residents 2D')
        task=meshy.poll_task('/openapi/v1/text-to-image',task_id,900)
        (d/'task.json').write_text(json.dumps(task,indent=2),encoding='utf-8')
        meshy.download(task['image_urls'][0],str(d/'residents.png'))
        if task.get('alpha_thumbnail_url'):
            meshy.download(task['alpha_thumbnail_url'],str(d/'residents_alpha.png'))
        meshy.record_task(str(d),task_id,'text-to-image','completed',prompt='Sanctuary residents 2D',files=['residents.png'])
        print(str(d.resolve()),flush=True)
        meshy._cmd_balance(None)
    finally:
        os.environ.pop('MESHY_API_KEY',None)

if __name__=='__main__': main()
