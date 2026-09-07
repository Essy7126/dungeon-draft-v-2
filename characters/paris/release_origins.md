# Origines des effets de Paris

Mesures visuelles prises sur les atlas RGBA de production, dans les poses réellement échantillonnées au signal `cast_release_reached`. Coordonnées de cellule 512 × 384 ; pivot (256, 320). Conversion locale : `(point - pivot) × 0,35`. Les points désignent le centre de la prise ou de la main, avec une précision visuelle de quelques pixels de source.

| Forme / geste | Pose E / N | Point E dans la cellule | Point N dans la cellule | Origine locale E | Origine locale N |
|---|---|---|---|---|---|
| Spectral, prise d’arc | 7 / 6 | (381, 190) | (367, 157) | (43,75 ; −45,50) | (38,85 ; −57,05) |
| Spectral, vortex | 9 / 10 | (242, 181) | (334, 246) | (−4,90 ; −48,65) | (27,30 ; −25,90) |
| Infernal, fouet tendu | 7 / 7 | (388, 153) | (390, 161) | (46,20 ; −58,45) | (46,90 ; −55,65) |
| Infernal, main d’incantation | 9 / 10 | (356, 170) | (355, 117) | (35,00 ; −52,50) | (34,65 ; −71,05) |
| Infernal, main tenant le fouet durant l’attraction | 9 / 10 | (173, 201) | (176, 219) | (−29,05 ; −41,65) | (−28,00 ; −35,35) |

Le vortex spectral E se concentre sous la main posée sur la poitrine ; en N, l’arc est abaissé et l’origine suit sa prise visible. Le sort d’attraction infernale utilise la main basse tenant le fouet, différente de la main ouverte employée par l’incantation de feu. `paris_infernal_pull` se distingue via `_pending_action_id == &"cast:paris_infernal_pull"` ; les autres sorts utilisent leur famille d’animation. Les mêmes poses servent au Pas du vortex, dont les portails restent placés sur les cellules de départ et d’arrivée réellement résolues.

S reprend E avec l’abscisse opposée ; W reprend N de la même manière. Aucune image n’est modifiée. `display_scale / 0,35` conserve l’attachement si l’échelle du sprite est ajustée.

Les anciennes origines étaient trop centrales : de dos, l’arc passait de x=10 à x=38,85 et le fouet de x=10 à x=46,90. Même de face, l’arc était à x=29 au lieu de x=43,75 et le fouet à x=30 au lieu de x=46,20.

Les flèches démarrent au lâcher puis sont confirmées 0,20 s après. Leur instance conserve son origine jusqu’à l’impact. Fouet, attraction, incantation et téléportation ont un délai de résolution nul. Pour une image lente traversant lâcher et récupération avant la reprise de la coroutine, Paris mémorise la position globale du lâcher ; le routeur la consomme une seule fois pour le sort correspondant. Une nouvelle action ou une annulation efface cet instantané. Les impacts confirmés et les cellules de téléportation restent dictés par le rapport de combat.

`test/unit/test_paris_release_origins.gd` vérifie les atlas de lâcher, les mesures en E/N et leurs miroirs, le lancement après une image lente, le fouet d’attraction après récupération et l’annulation de l’instantané.
