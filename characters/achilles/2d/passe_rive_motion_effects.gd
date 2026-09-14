extends Node2D

var backend: Node2D
var front := true


func _draw() -> void:
	if not is_instance_valid(backend):
		return
	var state: Dictionary = backend.get_motion_state()
	if state.is_empty():
		return
	var definition: Dictionary = state.definition
	var effects: Dictionary = state.effects
	var scale_value: float = state.scale
	draw_set_transform(-Vector2(576,662)*scale_value,0,Vector2.ONE*scale_value)
	if definition.id == "fauche" and effects.has("tips"):
		_draw_fauche(definition,effects,float(state.time))
	if definition.id == "vital_harvest" and front and effects.has("palms"):
		_draw_vital(effects,int(state.frame),float(state.time),String(state.facing))


func _draw_fauche(definition: Dictionary, effects: Dictionary, time: float) -> void:
	var starts := 0.0
	var tips: Array = effects.tips
	for i in range(1,mini(6,tips.size())):
		starts += float(definition.frames[i-1].duration_ms)
		var age := time*1000-starts
		if age<0 or age>=150:
			continue
		var is_front: bool = effects.get("front_segments",[false,false,false,true,true])[i-1]
		if front != is_front:
			continue
		var a := Vector2(tips[i-1][0],tips[i-1][1])
		var b := Vector2(tips[i][0],tips[i][1])
		var control := (a+b)*0.5+Vector2(0,65 if front else -80)
		var points := _curve(a,control,b)
		var fade := pow(1-age/150,1.4)
		_ribbon(points,25*fade,Color(0.5,0.86,0.71,0.35*fade))
		_ribbon(points,5*fade,Color(0.94,0.97,0.82,0.8*fade))


func _draw_vital(effects: Dictionary, frame: int, time: float, direction: String) -> void:
	if frame >= effects.palms.size():
		return
	var lift: float = backend.lift_at(time)
	var strength: float = [0,0.25,0.85,1,0.75,0][mini(frame,5)]
	for point: Array in effects.palms[frame]:
		var p := Vector2(point[0],point[1]-lift)
		draw_circle(p,21,Color(0.2,0.9,0.55,0.08*strength))
		draw_circle(p,11,Color(0.37,1,0.64,0.19*strength))
		draw_circle(p,4,Color(0.7,1,0.72,0.55*strength))
	var age := time-0.62
	if age<0 or age>=0.36:
		return
	var chest: Array = effects.chest[3]
	var start := Vector2(chest[0],chest[1]-backend.lift_at(0.62))
	var vector: Vector2 = {"E":Vector2(1,0.5),"S":Vector2(-1,0.5),"N":Vector2(1,-0.5),"W":Vector2(-1,-0.5)}[direction]
	var end := start+vector*350
	var u := clampf(age/0.36,0,1)
	var points := PackedVector2Array()
	for i in range(25):
		var t := lerpf(maxf(0,u-0.6),u,float(i)/24)
		points.append(start.lerp(end,t)+Vector2(0,-sin(t*PI)*28))
	_ribbon(points,22,Color(0.7,0.05,0.12,0.28*(1-u*0.5)))
	_ribbon(points,10,Color(1,0.2,0.24,0.7*(1-u*0.5)))
	_ribbon(points,3,Color(1,0.63,0.55,0.9*(1-u*0.5)))
	draw_circle(start,26*(1-u),Color(0.95,0.09,0.18,0.25*(1-u)))


func _curve(a: Vector2, control: Vector2, b: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(29):
		var u := float(i)/28
		points.append(a*(1-u)*(1-u)+control*2*u*(1-u)+b*u*u)
	return points


func _ribbon(points: PackedVector2Array, width: float, color: Color) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(points.size()):
		var normal := (points[mini(points.size()-1,i+1)]-points[maxi(0,i-1)]).normalized().orthogonal()
		var w := sin(PI*float(i)/float(points.size()-1))*width
		left.append(points[i]+normal*w)
		right.append(points[i]-normal*w)
	for i in range(right.size()-1,-1,-1):
		left.append(right[i])
	draw_colored_polygon(left,color)
