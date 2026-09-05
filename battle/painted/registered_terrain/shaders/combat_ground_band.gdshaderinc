#include "res://battle/painted/registered_terrain/shaders/combat_ground_surface.gdshaderinc"

uniform vec2 contour_grid[128];
uniform int contour_count=0;
uniform vec2 grid_origin=vec2(0);
uniform vec2 grid_axis_x=vec2(51.6,25.8);
uniform vec2 grid_axis_y=vec2(-51.6,25.8);
varying vec2 native_position;
varying vec4 band_modulate;
void vertex() { native_position=VERTEX; band_modulate=COLOR; }
void fragment() {
    vec2 native=native_position-grid_origin;
    float determinant=grid_axis_x.x*grid_axis_y.y-grid_axis_y.x*grid_axis_x.y;
    vec2 grid=vec2(native.x*grid_axis_y.y-native.y*grid_axis_y.x,
        native.y*grid_axis_x.x-native.x*grid_axis_x.y)/determinant;
    float distance_cells=10000.0;
    for(int i=0;i<128;i++) {
        if(i>=contour_count) { break; }
        vec2 a=contour_grid[i];
        vec2 b=contour_grid[(i+1)%max(contour_count,1)];
        vec2 ab=b-a;
        float along=clamp(dot(grid-a,ab)/max(dot(ab,ab),0.0001),0.0,1.0);
        distance_cells=min(distance_cells,length(grid-a-along*ab));
    }
    float coverage=gb_coverage(native_position,distance_cells);
    COLOR=vec4(gb_soil(native_position,distance_cells),coverage)*band_modulate;
}
