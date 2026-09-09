"""Geometric regressions for actual planted ankle and two-link articulation."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'output/monster-meshy-deps'))
import unittest
import numpy as np
from PIL import Image,ImageDraw
from articulated_animation import matrix,two_joint_ik,PaintedSkeleton

class ArticulationTests(unittest.TestCase):
    def test_ik_reaches_target_after_body_moves_and_rotates(self):
        for mirrored in (1,-1):
            hip=np.array([250.,200.]);knee=hip+[mirrored*16,48];foot=hip+[mirrored*3,87]
            parent=matrix(hip,mirrored*9,(7,6))
            for step in (-15,0,15):
                target=foot+[step,-8]
                first,second=two_joint_ik(hip,knee,foot,target,parent)
                transform=parent@matrix(hip,first)@matrix(knee,second)
                actual=(transform@np.r_[foot,1])[:2]
                np.testing.assert_allclose(actual,target,atol=1e-7)

    def test_unreachable_target_stops_at_limb_length(self):
        hip=np.array([100.,100.]);knee=np.array([120.,140.]);foot=np.array([120.,175.])
        first,second=two_joint_ik(hip,knee,foot,[500,500],np.eye(3))
        actual=(matrix(hip,first)@matrix(knee,second)@np.r_[foot,1])[:2]
        self.assertLessEqual(np.linalg.norm(actual-hip),np.linalg.norm(knee-hip)+np.linalg.norm(foot-knee))
        self.assertTrue(np.isfinite(actual).all())

    def test_ankle_stays_planted_and_foot_horizontal_during_body_recoil(self):
        image=Image.new('RGBA',(512,384));draw=ImageDraw.Draw(image)
        draw.line([(250,230),(238,270),(251,310)],fill='#667777',width=14)
        draw.rectangle((245,300,275,318),fill='#667777')
        parts=[{'name':'torso','parent':'root','pivot':[250,230],'z':0,'image':Image.new('RGBA',(512,384))},
               {'name':'leg_left','parent':'torso','pivot':[250,230],'z':1,'image':Image.new('RGBA',(512,384))},
               {'name':'shin_left','parent':'leg_left','pivot':[238,270],'end':[251,315],'z':2,'image':image}]
        puppet=PaintedSkeleton(image,parts,'rejeton_braise','E')
        ankle=np.array(puppet.by_name['shin_left']['end'])
        for recoil in (-9,0,9):
            transforms=puppet.matrices({'angles':{'torso':recoil},'shifts':{'torso':[recoil,8]},
                'ik':{'leg_left':[0,0]},'world_angles':{'foot_left':0}})
            actual=(transforms['foot_left']@np.r_[ankle,1])[:2]
            np.testing.assert_allclose(actual,ankle,atol=1e-7)
            self.assertAlmostEqual(transforms['foot_left'][1,0],0,places=7)

if __name__=='__main__':unittest.main()
