"""Sources et identités approuvées des monstres, sans initialisation distante."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

CREATURES = {'sentinelle_airain': {'source': 'meshy_output/20260908_125834_01-sentinelle-airain_01a080ab/source.png',
                       'identity': 'The exact approved squat bronze-and-ivory automaton. Short '
                                   'heavy spear in anatomical RIGHT hand, giant cracked round '
                                   'bronze shield in anatomical LEFT hand. Recessed small hollow '
                                   'helmet, turquoise slit eyes. Maintain its broad heavy armored '
                                   'torso and thick short legs; exact shield crack motif and armor '
                                   'design.'},
 'rejeton_braise': {'source': 'meshy_output/20260908_125835_02-rejeton-braise_01a080ab/source.png',
                    'identity': 'The exact approved small ash-grey imp, large long clawed '
                                'forearms, two short ivory horns, orange throat pouch, small '
                                'terracotta waistcloth. Two arms and two legs only. No tail, no '
                                'equipment. Preserve the master face and short hunched '
                                'proportions.'},
 'molosse_styx': {'source': 'meshy_output/20260908_125835_03-molosse-styx_01a080ab/source.png',
                  'identity': 'The exact approved SINGLE-HEADED charcoal-blue underworld hound '
                              'with broad ivory jaw and brow, three large ivory dorsal spines, '
                              'plain bronze collar, four canine legs and one tail. Preserve its '
                              'animal quadruped anatomy, no humanoid limbs.'},
 'lamie_lethe': {'source': 'meshy_output/20260908_125835_04-lamie-lethe_01a080ab/source.png',
                 'identity': 'The exact approved Greek serpent oracle: jade single coiled tail, '
                             'ivory face, bronze and ivory opaque armor, fan-shaped jade head '
                             'crest. Exactly TWO arms, no legs. Hooked staff in anatomical LEFT '
                             'hand as in the approved image, free anatomical RIGHT hand. Keep her '
                             'exact armor, crest and single tail.'}}
