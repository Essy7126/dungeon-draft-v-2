"""Small artist-facing controls for the Sentinelle pose study."""
bl_info={'name':'Dungeon Draft - Pose Lab','author':'Dungeon Draft','version':(1,0,0),'blender':(5,1,0),'category':'Animation'}
import bpy
from bpy.props import StringProperty, IntProperty


class DD_OT_study_view(bpy.types.Operator):
    bl_idname='dd.study_view'
    bl_label='Changer de vue'
    direction:StringProperty(default='E')
    def execute(self,context):
        camera=bpy.data.objects.get('Camera_'+self.direction)
        if camera:
            context.scene.camera=camera
            for area in context.screen.areas:
                if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
        return {'FINISHED'}


class DD_OT_study_pose(bpy.types.Operator):
    bl_idname='dd.study_pose'
    bl_label='Voir la pose'
    frame:IntProperty(default=1)
    def execute(self,context):
        if context.screen.is_animation_playing:bpy.ops.screen.animation_cancel(restore_frame=False)
        context.scene.frame_set(self.frame)
        return {'FINISHED'}


class DD_OT_study_action(bpy.types.Operator):
    bl_idname='dd.study_action'
    bl_label='Mode de lecture'
    action:StringProperty(default='Estoc_Blocking')
    def execute(self,context):
        rig=bpy.data.objects['Sentinelle_Rig'];action=bpy.data.actions[self.action]
        rig.animation_data.action=action
        if action.slots:rig.animation_data.action_slot=action.slots[0]
        context.scene.frame_set(context.scene.frame_current)
        return {'FINISHED'}


class DD_OT_study_controls(bpy.types.Operator):
    bl_idname='dd.study_controls'
    bl_label='Afficher / masquer les contrôles'
    def execute(self,context):
        rig=bpy.data.objects['Sentinelle_Rig']
        for area in context.screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.overlay.show_overlays=not area.spaces.active.overlay.show_overlays
        for ob in context.selected_objects:ob.select_set(False)
        rig.select_set(True);context.view_layer.objects.active=rig
        return {'FINISHED'}


class DD_PT_study(bpy.types.Panel):
    bl_label='Sentinelle - Étude de poses'
    bl_space_type='VIEW_3D';bl_region_type='UI';bl_category='Sentinelle'
    @classmethod
    def poll(cls,context):return bpy.data.objects.get('Sentinelle_Rig') is not None
    def draw(self,context):
        layout=self.layout
        layout.label(text='Estoc : mécanique à valider',icon='ARMATURE_DATA')
        layout.label(text='Même mannequin, quatre vues')
        row=layout.row(align=True)
        for d in 'ESWN':row.operator('dd.study_view',text=d).direction=d
        layout.separator()
        row=layout.row(align=True)
        row.operator('dd.study_action',text='Poses tenues').action='Estoc_Blocking'
        row.operator('dd.study_action',text='Interpolé').action='Estoc_Preview'
        layout.operator('screen.animation_play',text='Lire / Pause',icon='PLAY')
        layout.prop(context.scene,'frame_current',text='Image')
        grid=layout.grid_flow(row_major=True,columns=2,even_columns=True)
        for f,label in [(1,'Garde'),(6,'Charge'),(10,'Appui'),(13,'Contact'),(16,'Freinage'),(25,'Retour')]:
            grid.operator('dd.study_pose',text=label).frame=f
        layout.separator()
        layout.operator('dd.study_controls',text='Contrôles du rig',icon='BONE_DATA')
        refs=bpy.data.collections.get('Source_references')
        if refs:layout.prop(refs,'hide_viewport',text='Masquer les dessins sources')
        layout.label(text='Contact à 0,40 s / durée 0,80 s')


CLASSES=[DD_OT_study_view,DD_OT_study_pose,DD_OT_study_action,DD_OT_study_controls,DD_PT_study]
def register():
    for cls in CLASSES:bpy.utils.register_class(cls)
def unregister():
    for cls in reversed(CLASSES):bpy.utils.unregister_class(cls)
if __name__=='__main__':register()
