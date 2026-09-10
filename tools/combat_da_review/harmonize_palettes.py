import json
from pathlib import Path
root = Path.cwd()
colors = {
"greek_drawn_courtyard_v1": ("#3c5056","#7c8e85","#b4b897"),
"ashen_hell_courtyard_v1": ("#303b42","#596466","#9b9380"),
"silent_judgment_courtyard_v1": ("#677578","#9fa59b","#d1cdb6"),
"lethe_crossing_v1": ("#495f60","#83968c","#b8c0a4"),
"black_oath_temple_v1": ("#253b46","#506a72","#899a98"),
}
def replace_object(text, key, value):
    token = json.dumps(key) + ":"
    start = text.find(token)
    if start < 0:
        pos = text.rfind("}")
        return text[:pos].rstrip() + ',\n  ' + token + ' ' + json.dumps(value,indent=2).replace('\n','\n  ') + '\n}\n'
    content_start = text.index("{", start)
    depth, end = 0, content_start
    for end in range(content_start, len(text)):
        if text[end] == "{": depth += 1
        if text[end] == "}":
            depth -= 1
            if depth == 0: break
    return text[:content_start] + json.dumps(value,indent=2).replace('\n','\n  ') + text[end+1:]
for name, (shade, body, light) in colors.items():
    path=root/"data/arenas"/name/"terrain_plan.json"
    text=path.read_text()
    plan=json.loads(text)
    floor=plan.get("floor_palette",{})
    floor.update(shade=shade, body=body, light=light)
    if name=="greek_drawn_courtyard_v1":
        floor.update(warmth=[-.025,-.008,.012,.025],painted_steps=.18,bevel_flatten_strength=.92)
    props=plan.get("props_palette",{})
    props.update(ink=shade,top=light,left=body,right=shade,highlight=light,bench=light)
    text=replace_object(text,"floor_palette",floor)
    text=replace_object(text,"props_palette",props)
    result=json.loads(text)
    check=json.loads(json.dumps(result))
    original=json.loads(json.dumps(plan))
    for key in ("floor_palette","props_palette"):
        check.pop(key,None); original.pop(key,None)
    assert check==original
    path.write_text(text)
manifest_path=root/"assets/catabase/combat_da_v1/manifest.json"
manifest=json.loads(manifest_path.read_text())
for entry in manifest["maps"]:
    entry["stone_palette"]=list(colors[entry["arena"]])
    entry["geometry_and_other_layers_unchanged"]=True
manifest["policy"]="Original art preserved. Land texture, UV sampling and local stone/prop palettes only. Native geometry, water, foreground sprites and interface unchanged."
manifest_path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n")
