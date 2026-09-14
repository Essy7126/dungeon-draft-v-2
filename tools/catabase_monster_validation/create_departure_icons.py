"""Original vector silhouettes for the first six builds. No external artwork."""
from pathlib import Path

DEST = Path(__file__).resolve().parents[2] / 'assets/catabase/preparation'
SHAPES = {
    'weapon_marteau': '<path d="M53 108 82 55l12 7-28 54z" fill="#ba8655"/><path d="m46 33 20-15 49 28-4 23-22 9-47-29z" fill="#d5b577"/><path d="m60 28 43 25-6 13-43-25"/>',
    'weapon_xiphos': '<path d="m40 89 7-19 42-46 11-5-2 16-41 49z" fill="#e1d6aa"/><path d="m35 82 29 19M46 91l-14 19"/><path d="m99 59 23 10-1 24-20 20-20-20-2-24z" fill="#bca16c"/><path d="m100 69 1 33m-13-18h24"/>',
    'weapon_disque': '<circle cx="80" cy="70" r="40" fill="#be935a"/><circle cx="80" cy="70" r="29" fill="#557b78"/><circle cx="80" cy="70" r="10" fill="#dfc787"/><path d="m65 46 27 47M101 53 59 85"/><path d="M26 72q-9 30 22 43m-19-5 19 5-5-18" fill="none" stroke="#79c8b4"/>',
    'weapon_hampe': '<path d="m48 119 46-85 8 4-45 85z" fill="#ac7853"/><path d="M86 51q-20-18 9-42-1 20 11 18 24 27-6 35z" fill="#e8aa64"/><path d="m95 47 6-16 7 19" fill="#f0d4a0"/>',
    'weapon_lame': '<path d="m44 101 12-29 46-53 3 24-14 7 0 17-13 3-14 28z" fill="#bcbda3"/><path d="m49 100 27 10M59 104l-12 20"/><path d="m83 53-17 34m24-15q14 23 0 26-13-3 0-26" fill="#a65159"/>',
    'weapon_arc': '<path d="M52 20q77 49 3 99l16-52z" fill="#bd975c"/><path d="m52 20 10 49-7 50M33 76l78-13m-13-8 13 8-10 13" fill="none"/><circle cx="84" cy="105" r="12" fill="#ddba69"/>',
    'armor_airain': '<path d="m46 26 18-9q16 16 32 0l18 9-7 28 6 48q-33 22-65 0l6-48z" fill="#c29a60"/><path d="m58 53 19 8 24-8M55 86l24 7 27-7m-27-55v60"/>',
    'armor_sceau': '<path d="m52 25 17-10 20 0 19 10 13 77-40 21-43-21z" fill="#647d8d"/><path d="m80 36 21 34-21 32-22-32z" fill="#9ad2c7"/><path d="m80 51 9 19-9 15-10-15z" fill="#b79368"/>',
    'armor_mixte': '<path d="m46 24 19-9 14 13 16-13 20 9-8 40 7 43-34 13-35-13 8-43z" fill="#d9c89e"/><path d="m64 29 36 62M58 43l33 62M96 30 60 91m42-44-32 59" stroke="#648e84"/>',
    'armor_legere': '<path d="m62 19 29-5 12 18-19 77-32-6-14-26z" fill="#6da798"/><path d="m89 26-17 70m-31-21 46 9"/><path d="m49 102 13 3 5 18-31 3-1-10zM85 101l13 2 16 16-29 7-8-13z" fill="#c39b68"/>',
    'relic_clou': '<path d="m45 31 10-14 54 21-3 18-22-7-26 64-12 12 1-20 24-62z" fill="#c9ac77"/><path d="m61 29 36 14M72 55l-17 46"/>',
    'relic_urne': '<path d="M56 31h48l-7 20q28 20 9 52-26 22-51 0-18-29 8-52z" fill="#bc9662"/><path d="M63 23h33M48 60q-24-15-17 11l20 12m61-23q26-13 17 13l-19 12M57 87h47"/><path d="m68 62 13 14 13-14" fill="#5f958e"/>',
    'relic_fil': '<path d="M51 35q33-13 57 0v60q-29 18-57 0z" fill="#c6a879"/><path d="M49 27h61M49 103h61M55 49l48 13-48 10 48 12" stroke="#82c9b6"/><path d="M98 91q35 0 23 27-9 13-22 4" fill="none" stroke="#82c9b6"/>',
    'relic_coupe': '<path d="M45 29h72q-2 40-31 49v26h20v11H56v-11h18V78Q47 71 45 29z" fill="#d0ad77"/><path d="M53 39h55q-8 26-28 26-20-2-27-26" fill="#ac5663"/><path d="M42 37q-21 2-5 25l20 4m64-29q19 2 3 25l-19 4" fill="none"/>',
    'relic_meche': '<path d="M56 115q-19-32 11-41t6-31" fill="none" stroke="#c6ae81" stroke-width="12"/><path d="M69 58Q36 36 82 10q-4 24 13 17 28 27-1 45z" fill="#e4a363"/><path d="m76 51 8-23 11 24-9 12z" fill="#f2d599"/>',
    'relic_obole': '<path d="M72 22a46 46 0 0 0 0 91l-4-27 13-17-12-12z" fill="#d1ac63"/><path d="M86 22a46 46 0 0 1 3 91l-5-25 12-18-12-13z" fill="#b78b4f"/><path d="M58 43q-30 29 1 49m42-48q24 27 1 48" fill="none"/>',
    'supply_onguent': '<path d="m56 35 49-1 7 16-6 63H51l-5-63z" fill="#81ab98"/><path d="M54 22h52v16H54z" fill="#c6a574"/><path d="M69 63h21v12h12v20H89v12H69V95H57V75h12z" fill="#e3d0a6"/>',
    'supply_souffle': '<path d="M67 18h25v31q40 46 12 64H55q-23-21 12-64z" fill="#6a9dab"/><path d="M63 16h34v15H63z" fill="#caa374"/><path d="M60 86q15-20 33-11t9 24M65 101q-4-13 23-15" fill="none" stroke="#c6e3d6"/>',
    'supply_plaque': '<path d="m41 30 72-9 9 82-72 14z" fill="#c7a26a"/><path d="m56 44 43-5 7 52-43 7z" fill="#648982"/><path d="m78 49 18 13-11 25-19-19z" fill="#e0c895"/>',
    'supply_sel': '<path d="m59 34 18 8 21-10-5 22q37 44 15 61H52q-29-18 15-61z" fill="#bda584"/><path d="M62 53h34"/><path d="m68 80 12-10 10 13-9 15zM55 99l8-8 7 11-9 6m34-19 8-5 5 10-8 4" fill="#f2e8c8"/>',
}
DEST.mkdir(parents=True, exist_ok=True)
for name, shape in SHAPES.items():
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="160" height="140" viewBox="0 0 160 140"><g stroke="#253c40" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">' + shape + '</g></svg>\n'
    (DEST / (name + '.svg')).write_text(svg, encoding='utf-8')
