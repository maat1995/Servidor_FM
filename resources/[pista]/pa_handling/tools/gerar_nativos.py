# -*- coding: utf-8 -*-
"""
Gera data/nativos.lua (fichas dos carros nativos do GTA) a partir de:
  - FICHAS: carro real de inspiração + dados reais (escritos à mão, abaixo)
  - vanilla.json: estatísticas originais do GTA (para os carros sem ficha)

Carro sem ficha recebe uma ficha automática: mantém a ordem original dentro
da classe (o mais rápido continua o mais rápido), mas espremida na faixa
realista da classe (FAIXAS).

Rodar:  python tools/gerar_nativos.py   (dentro da pasta pa_handling)
"""
import json, os

AQUI = os.path.dirname(os.path.abspath(__file__))

# Tração: 'D' dianteira, 'T' traseira, '4x4' integral
# (real, cv, kg, tracao, marchas, zero100, vmax, pneu)
# zero100 = None para carro que mal passa de 100 km/h: usa zero60 (último campo)
F = {
    # ------------------------------------------------------------ COMPACTOS
    'blista':     ('Honda Civic 1.5 (5ª geração)',            92,  960, 'D', 5, 10.8, 180, 'popular'),
    'brioso':     ('Fiat 500 Abarth 595',                    140, 1110, 'D', 5,  7.8, 209, 'medio'),
    'brioso2':    ('Fiat Nuova 500 (1957)',                   18,  500, 'T', 4, None,  95, 'classico', 20.0),
    'brioso3':    ('Fiat-Abarth 695 SS (1964)',               38,  480, 'T', 4, 18.0, 140, 'classico'),
    'weevil':     ('Volkswagen Fusca 1300',                   46,  820, 'T', 4, 23.0, 125, 'classico'),
    'dilettante': ('Toyota Prius (2ª geração)',              110, 1320, 'D', None, 10.9, 170, 'popular'),
    'prairie':    ('Hyundai Tiburon 2.0 (1ª geração)',       140, 1190, 'D', 5,  8.9, 205, 'popular'),
    'issi2':      ('Mini Cooper 1.6 (R56)',                  122, 1150, 'D', 6,  9.1, 203, 'medio'),
    'rhapsody':   ('AMC Gremlin 3.8 (1972)',                 110, 1250, 'T', 3, 12.5, 160, 'classico'),
    'asbo':       ('Vauxhall Nova SR 1.3 / Corsa A',          72,  820, 'D', 5, 11.5, 170, 'popular'),
    'club':       ('Volkswagen Polo G40 (1991)',             115,  850, 'D', 5,  8.1, 196, 'popular'),
    'issi3':      ('Mini Cooper S 1275 (clássico)',           76,  650, 'D', 4, 10.9, 155, 'classico'),
    'panto':      ('Smart ForTwo',                            71,  830, 'T', 5, 13.3, 145, 'popular'),
    'kanjo':      ('Honda Civic Type R (EK9)',               185, 1070, 'D', 5,  6.7, 225, 'esportivo'),
    # ------------------------------------------------------------ SEDÃS
    'emperor':    ('Cadillac Fleetwood Brougham (anos 80)',  140, 1950, 'T', 4, 13.5, 175, 'classico'),
    'ingot':      ('Volvo 240 Station Wagon',                114, 1300, 'T', 4, 11.5, 175, 'popular'),
    'regina':     ('Chevrolet Caprice Wagon (anos 80)',      150, 1900, 'T', 3, 12.5, 170, 'classico'),
    'romero':     ('Cadillac carro funerário (anos 90)',     185, 2600, 'T', 4, 11.5, 180, 'medio'),
    'stretch':    ('Lincoln Town Car limusine',              220, 3000, 'T', 4, 12.5, 170, 'medio'),
    'surge':      ('Chevrolet Volt',                         150, 1720, 'D', None, 9.0, 160, 'popular'),
    'asea':       ('Chevrolet Cobalt 1.4',                   102, 1100, 'D', 5, 11.6, 177, 'popular'),
    'asterope':   ('Toyota Camry 2.4 (XV40)',                160, 1450, 'D', 5,  9.5, 210, 'medio'),
    'fugitive':   ('Chevrolet Omega 3.6 V6 (Holden Commodore)', 258, 1700, 'T', 5, 7.5, 240, 'medio'),
    'intruder':   ('Toyota Camry 2.4 (XV30)',                155, 1440, 'D', 4, 10.0, 200, 'medio'),
    'premier':    ('Dodge Avenger 2.4',                      173, 1500, 'D', 4,  9.8, 200, 'medio'),
    'primo':      ('Chrysler 300M 3.5 V6',                   253, 1610, 'D', 4,  8.0, 230, 'medio'),
    'schafter2':  ('Mercedes-Benz E 350 (W212)',             272, 1700, 'T', 6,  6.8, 250, 'medio'),
    'stanier':    ('Ford Crown Victoria 4.6 V8',             224, 1800, 'T', 4,  9.0, 190, 'medio'),
    'tailgater':  ('Audi A6 3.0 TFSI quattro (C6)',          290, 1750, '4x4', 6, 5.9, 250, 'medio'),
    'tailgater2': ('Audi S4 (B9)',                           354, 1630, '4x4', 6, 4.7, 250, 'esportivo'),
    'washington': ('Lincoln Town Car 4.6 V8',                239, 1900, 'T', 4,  9.0, 190, 'medio'),
    'stratum':    ('Subaru Legacy Wagon 2.0 (anos 90)',      125, 1300, '4x4', 5, 11.0, 195, 'popular'),
    'glendale':   ('Mercedes-Benz 280E (W114)',              185, 1450, 'T', 4, 10.5, 200, 'classico'),
    'asterope2':  ('Toyota Camry XSE V6 (XV70)',             301, 1650, 'D', 6,  6.0, 210, 'medio'),
    'warrener':   ('Datsun 510 1.6',                          96,  940, 'T', 4, 13.0, 165, 'classico'),
    'warrener2':  ('Datsun 510 preparado (1.8)',             140,  920, 'T', 5,  8.8, 190, 'classico'),
    'cognoscenti':('Bentley Flying Spur W12',                625, 2475, '4x4', 6, 4.6, 322, 'esportivo'),
    'cognoscenti2':('Bentley Flying Spur W12 blindado',      625, 2975, '4x4', 6, 5.6, 290, 'esportivo'),
    'cog55':      ('Bentley Mulsanne 6.75 V8',               512, 2585, 'T', 6,  5.3, 296, 'esportivo'),
    'superd':     ('Rolls-Royce Phantom VII',                460, 2560, 'T', 6,  5.9, 240, 'medio'),
    'vorschlaghammer': ('Mercedes-Benz 560 SEL (W126)',      300, 1760, 'T', 4,  7.2, 250, 'medio'),
    'chavosv6':   ('Honda Accord V6 (2003)',                 240, 1500, 'D', 6,  6.8, 230, 'medio'),
    'deity':      ('Bentley Flying Spur W12 (2020)',         635, 2437, '4x4', 6, 3.8, 333, 'esportivo'),
    'cinquemila': ('Maserati Quattroporte GTS (VI)',         530, 1900, 'T', 6,  4.7, 310, 'esportivo'),
    'stafford':   ('Rolls-Royce Silver Wraith (anos 50)',    120, 2200, 'T', 4, 25.0, 140, 'classico'),
    # ------------------------------------------------------------ COUPÉS
    'sentinel':   ('BMW 335i Coupé (E92)',                   306, 1600, 'T', 6,  5.6, 250, 'medio'),
    'zion':       ('BMW 650i (E63)',                         367, 1700, 'T', 6,  5.4, 250, 'medio'),
    'f620':       ('Jaguar XK 5.0 (X150)',                   385, 1650, 'T', 6,  5.5, 250, 'esportivo'),
    'felon':      ('Maserati GranTurismo 4.2',               405, 1880, 'T', 6,  5.2, 285, 'esportivo'),
    'felon2':     ('Maserati GranCabrio',                    440, 1980, 'T', 6,  5.4, 283, 'esportivo'),
    'cogcabrio':  ('Bentley Continental GTC W12',            560, 2495, '4x4', 6, 4.8, 314, 'esportivo'),
    'exemplar':   ('Aston Martin Rapide V12',                477, 1990, 'T', 6,  5.3, 296, 'esportivo'),
    'windsor':    ('Rolls-Royce Wraith',                     632, 2360, 'T', 6,  4.6, 250, 'esportivo'),
    'windsor2':   ('Rolls-Royce Dawn',                       570, 2560, 'T', 6,  4.9, 250, 'esportivo'),
    'postlude':   ('Honda Prelude 2.2 VTEC (4ª geração)',    200, 1270, 'D', 5,  7.0, 228, 'medio'),
    'fr36':       ('Infiniti Q60 Red Sport',                 400, 1780, 'T', 6,  4.5, 250, 'esportivo'),
    'kanjosj':    ('Honda Civic Si Coupé (1999)',            160, 1140, 'D', 5,  7.6, 220, 'medio'),
    # ------------------------------------------------------------ ESPORTIVOS
    'elegy2':     ('Nissan GT-R (R35)',                      550, 1740, '4x4', 6, 3.0, 315, 'super'),
    'elegy':      ('Nissan Skyline GT-R (R32)',              280, 1430, '4x4', 5, 5.6, 250, 'esportivo'),
    'sultan':     ('Mitsubishi Lancer Evolution IX',         280, 1420, '4x4', 5, 5.0, 250, 'esportivo'),
    'sultan2':    ('Subaru Impreza WRX STI (GC8)',           280, 1270, '4x4', 5, 4.9, 245, 'esportivo'),
    'sultanrs':   ('Subaru Impreza 22B STI',                 280, 1270, '4x4', 5, 4.7, 248, 'esportivo'),
    'futo':       ('Toyota Corolla Levin AE86',              130,  950, 'T', 5,  8.5, 200, 'medio'),
    'futo2':      ('Toyota Sprinter Trueno AE86 preparado',  160,  940, 'T', 5,  7.6, 205, 'medio'),
    'jester':     ('Honda NSX (2016)',                       573, 1725, '4x4', 6, 3.1, 307, 'super'),
    'jester3':    ('Toyota Supra Turbo (Mk4)',               330, 1500, 'T', 6,  4.9, 285, 'esportivo'),
    'jester4':    ('Toyota GR Supra (A90)',                  340, 1540, 'T', 6,  4.3, 250, 'esportivo'),
    'zr350':      ('Mazda RX-7 (FD)',                        280, 1280, 'T', 5,  5.0, 255, 'esportivo'),
    'rt3000':     ('Honda S2000',                            240, 1260, 'T', 6,  6.2, 240, 'esportivo'),
    'calico':     ('Toyota Celica GT-Four (ST205)',          255, 1380, '4x4', 5, 5.9, 245, 'esportivo'),
    'remus':      ('Nissan Silvia S13 (SR20DET)',            205, 1180, 'T', 5,  6.5, 230, 'medio'),
    'euros':      ('Nissan 350Z',                            287, 1460, 'T', 6,  5.8, 250, 'esportivo'),
    'growler':    ('Porsche 718 Cayman GT4',                 420, 1420, 'T', 6,  4.4, 304, 'esportivo'),
    'comet2':     ('Porsche 911 Carrera (997)',              325, 1415, 'T', 6,  4.9, 285, 'esportivo'),
    'comet3':     ('Porsche 911 Turbo (930)',                300, 1335, 'T', 4,  5.2, 260, 'esportivo'),
    'comet6':     ('Porsche 911 Carrera S (992)',            450, 1515, 'T', 6,  3.7, 308, 'super'),
    'comet7':     ('Porsche 911 Carrera S Cabriolet (992)',  450, 1585, 'T', 6,  3.9, 306, 'super'),
    'ninef':      ('Audi R8 V10',                            525, 1620, '4x4', 6, 3.9, 316, 'super'),
    'carbonizzare': ('Ferrari California',                   460, 1735, 'T', 6,  3.8, 310, 'super'),
    'banshee':    ('Dodge Viper SRT-10',                     600, 1560, 'T', 6,  3.9, 325, 'super'),
    'feltzer2':   ('Mercedes-Benz SL 500 (R231)',            435, 1785, 'T', 6,  4.6, 250, 'esportivo'),
    'massacro':   ('Aston Martin Vanquish (2013)',           573, 1739, 'T', 6,  4.1, 295, 'super'),
    'rapidgt':    ('Aston Martin DB9',                       477, 1785, 'T', 6,  4.6, 306, 'esportivo'),
    'schwarzer':  ('Mercedes-Benz C 63 AMG Coupé (W204)',    457, 1730, 'T', 6,  4.4, 250, 'esportivo'),
    'buffalo':    ('Dodge Charger 3.6 V6 (2011)',            296, 1800, 'T', 5,  7.0, 225, 'medio'),
    'buffalo2':   ('Dodge Charger R/T 5.7 HEMI',             375, 1900, 'T', 5,  5.6, 240, 'muscle'),
    'kuruma':     ('Mitsubishi Lancer Evolution X',          295, 1520, '4x4', 6, 4.9, 250, 'esportivo'),
    'kuruma2':    ('Mitsubishi Lancer Evolution X blindado', 295, 2020, '4x4', 6, 6.4, 225, 'esportivo'),
    'penumbra':   ('Mitsubishi Eclipse GSX (2ª geração)',    210, 1450, '4x4', 5, 6.9, 230, 'medio'),
    'khamelion':  ('Fisker Karma',                           409, 2400, 'T', None, 5.9, 200, 'esportivo'),
    'coquette':   ('Chevrolet Corvette C6',                  437, 1460, 'T', 6,  4.2, 306, 'esportivo'),
    'coquette4':  ('Chevrolet Corvette Stingray C8',         502, 1530, 'T', 6,  3.0, 312, 'super'),
    'vstr':       ('Cadillac CTS-V (2016)',                  649, 1880, 'T', 6,  3.7, 322, 'esportivo'),
    'drafter':    ('Audi RS7 Sportback (2020)',              600, 2065, '4x4', 6, 3.6, 305, 'esportivo'),
    'raiden':     ('Tesla Model S P100D',                    772, 2250, '4x4', None, 2.7, 250, 'esportivo'),
    'streiter':   ('Porsche Cayenne Turbo (2015)',           520, 2185, '4x4', 6, 4.5, 279, 'esportivo'),
    'tropos':     ('Lancia Stratos HF',                      190,  980, 'T', 5,  6.8, 230, 'esportivo'),
    'flashgt':    ('Ford Focus RS (Mk3)',                    350, 1530, '4x4', 6, 4.7, 266, 'esportivo'),
    'schlagen':   ('Mercedes-AMG GT S',                      510, 1645, 'T', 6,  3.8, 310, 'super'),
    'italigto':   ('Ferrari 812 Superfast',                  800, 1630, 'T', 6,  2.9, 340, 'super'),
    'italirsx':   ('Ferrari SF90 Stradale',                 1000, 1570, '4x4', 6, 2.5, 340, 'super'),
    'jugular':    ('Jaguar XE SV Project 8',                 600, 1745, '4x4', 6, 3.7, 322, 'esportivo'),
    'tenf':       ('Audi R8 V10 Plus (2ª geração)',          610, 1555, '4x4', 6, 3.2, 330, 'super'),
    'corsita':    ('Maserati MC20',                          630, 1500, 'T', 6,  2.9, 325, 'super'),
    'sugoi':      ('Honda Civic Type R (FK8)',               320, 1380, 'D', 6,  5.7, 272, 'esportivo'),
    'komoda':     ('Alfa Romeo Giulia Quadrifoglio',         510, 1580, 'T', 6,  3.9, 307, 'esportivo'),
    'seven70':    ('Aston Martin DB11 V12',                  608, 1875, 'T', 6,  3.9, 322, 'super'),
    'specter':    ('Aston Martin DB10',                      510, 1650, 'T', 6,  4.0, 305, 'esportivo'),
    'lynx':       ('Jaguar F-Type R',                        550, 1665, 'T', 6,  4.0, 300, 'esportivo'),
    'bestiagts':  ('Ferrari FF',                             660, 1880, '4x4', 6, 3.7, 335, 'super'),
    'vectre':     ('Lexus SC400 (Z30)',                      260, 1650, 'T', 4,  7.0, 250, 'medio'),
    'sentinel3':  ('BMW M3 (E30)',                           200, 1200, 'T', 5,  6.9, 235, 'esportivo'),
    'blista2':    ('Honda CR-X Si (1988)',                   108,  900, 'D', 5,  8.6, 200, 'medio'),
    # ------------------------------------------------------------ SUPER
    'adder':      ('Bugatti Veyron 16.4',                   1001, 1888, '4x4', 6, 2.5, 407, 'super'),
    'zentorno':   ('Lamborghini Aventador LP700-4',          700, 1575, '4x4', 6, 2.9, 350, 'super'),
    't20':        ('McLaren P1',                             916, 1490, 'T', 6,  2.8, 350, 'super'),
    'osiris':     ('Pagani Huayra',                          730, 1350, 'T', 6,  3.0, 370, 'super'),
    'entityxf':   ('Koenigsegg CCX',                         806, 1456, 'T', 6,  3.2, 395, 'super'),
    'entity2':    ('Koenigsegg Agera RS',                   1360, 1395, 'T', 6,  2.8, 447, 'super'),
    'turismor':   ('Ferrari LaFerrari',                      963, 1585, 'T', 6,  2.4, 350, 'super'),
    'cheetah':    ('Ferrari Enzo',                           660, 1365, 'T', 6,  3.3, 350, 'super'),
    'infernus':   ('Lamborghini Murciélago LP640',           640, 1665, '4x4', 6, 3.4, 340, 'super'),
    'vacca':      ('Lamborghini Gallardo',                   520, 1520, '4x4', 6, 4.0, 315, 'super'),
    'bullet':     ('Ford GT (2005)',                         550, 1520, 'T', 6,  3.8, 330, 'super'),
    'voltic':     ('Tesla Roadster (2008)',                  252, 1235, 'T', None, 3.9, 201, 'esportivo'),
    'fmj':        ('Jaguar XJ220',                           550, 1470, 'T', 5,  3.9, 341, 'super'),
    'italigtb':   ('Ferrari 488 GTB',                        670, 1475, 'T', 6,  3.0, 330, 'super'),
    'italigtb2':  ('Ferrari 488 Pista',                      720, 1385, 'T', 6,  2.85, 340, 'super'),
    'nero':       ('Bugatti Chiron',                        1500, 1995, '4x4', 6, 2.4, 420, 'super'),
    'xa21':       ('Jaguar C-X75',                           890, 1350, '4x4', 6, 3.0, 354, 'super'),
    'tempesta':   ('Lamborghini Huracán EVO',                640, 1422, '4x4', 6, 2.9, 325, 'super'),
    'pfister811': ('Porsche 918 Spyder',                     887, 1675, '4x4', 6, 2.6, 345, 'super'),
    'gp1':        ('McLaren F1',                             627, 1140, 'T', 6,  3.2, 386, 'super'),
    'cyclone':    ('Rimac Concept One',                     1088, 1950, '4x4', None, 2.5, 355, 'super'),
    'krieger':    ('Mercedes-AMG Project One',              1063, 1695, '4x4', 6, 2.9, 352, 'super'),
    'torero2':    ('Lamborghini Countach LPI 800-4',         814, 1595, '4x4', 6, 2.8, 355, 'super'),
    # ------------------------------------------------------------ MUSCLE
    'dominator':  ('Ford Mustang GT 5.0 (2011)',             418, 1640, 'T', 6,  4.6, 250, 'muscle'),
    'dominator9': ('Ford Mustang GT (2024)',                 486, 1750, 'T', 6,  4.3, 250, 'muscle'),
    'gauntlet':   ('Dodge Challenger SRT8 (2010)',           431, 1880, 'T', 6,  4.9, 280, 'muscle'),
    'gauntlet3':  ('Dodge Challenger R/T 426 Hemi (1970)',   425, 1700, 'T', 4,  5.8, 235, 'muscle'),
    'gauntlet4':  ('Dodge Challenger SRT Hellcat',           717, 1950, 'T', 6,  3.6, 320, 'muscle'),
    'vigero':     ('Chevrolet Camaro SS 396 (1969)',         375, 1550, 'T', 4,  6.0, 210, 'muscle'),
    'vigero2':    ('Chevrolet Camaro ZL1 (2019)',            659, 1750, 'T', 6,  3.5, 318, 'muscle'),
    'vigero3':    ('Chevrolet Camaro ZL1 Conversível',       659, 1820, 'T', 6,  3.7, 314, 'muscle'),
    'dukes':      ('Dodge Charger R/T 440 (1970)',           380, 1700, 'T', 4,  6.3, 220, 'muscle'),
    'sabregt':    ('Buick Grand National (1987)',            245, 1600, 'T', 4,  5.8, 200, 'muscle'),
    'ruiner':     ('Pontiac Firebird Trans Am (1982)',       165, 1520, 'T', 4,  9.5, 190, 'muscle'),
    'phoenix':    ('Pontiac Firebird Trans Am 6.6 (1977)',   200, 1650, 'T', 3,  8.5, 190, 'muscle'),
    'picador':    ('Chevrolet El Camino 350 (1970)',         300, 1700, 'T', 3,  7.5, 200, 'muscle'),
    'virgo':      ('Lincoln Continental Mark III (1969)',    365, 2200, 'T', 3,  8.5, 200, 'classico'),
    'voodoo2':    ('Chevrolet Impala 5.4 V8 (1964)',         250, 1700, 'T', 3,  9.0, 190, 'classico'),
    'impaler':    ('Chevrolet Impala SS 427 (1967)',         385, 1730, 'T', 3,  6.5, 215, 'muscle'),
    'coquette3':  ('Chevrolet Corvette C2 Sting Ray (1963)', 360, 1410, 'T', 4,  5.9, 230, 'muscle'),
    'buffalo4':   ('Dodge Charger SRT Hellcat',              717, 2075, 'T', 6,  3.7, 327, 'muscle'),
    'buffalo5':   ('Dodge Charger Daytona EV',               680, 2600, 'T', None, 3.3, 260, 'muscle'),
    'weevil2':    ('Volkswagen Fusca 1600 preparado',         90,  820, 'T', 4, 13.0, 160, 'classico'),
    # ------------------------------------------------------------ CLÁSSICOS ESPORTIVOS
    'jb700':      ('Aston Martin DB5',                       282, 1500, 'T', 5,  8.0, 233, 'classico'),
    'monroe':     ('Lamborghini Miura P400',                 350, 1180, 'T', 5,  6.7, 280, 'classico'),
    'stingergt':  ('Ferrari 250 GTO',                        300,  880, 'T', 5,  6.1, 280, 'classico'),
    'turismo2':   ('Ferrari F40',                            478, 1100, 'T', 5,  4.1, 324, 'esportivo'),
    'infernus2':  ('Lamborghini Diablo VT',                  492, 1625, '4x4', 5, 4.0, 325, 'esportivo'),
    'cheetah2':   ('Ferrari Testarossa',                     390, 1506, 'T', 5,  5.8, 290, 'classico'),
    'torero':     ('Lamborghini Countach LP400',             375, 1065, 'T', 5,  5.6, 290, 'classico'),
    'coquette2':  ('Chevrolet Corvette C1 (1962)',           360, 1380, 'T', 4,  6.5, 210, 'classico'),
    'tornado':    ('Chevrolet Bel Air 283 V8 (1957)',        185, 1580, 'T', 3, 11.5, 175, 'classico'),
    'mamba':      ('Shelby Cobra 427',                       425, 1070, 'T', 4,  4.5, 265, 'classico'),
    'feltzer3':   ('Mercedes-Benz 300 SL Gullwing',          215, 1300, 'T', 4,  9.3, 235, 'classico'),
    'z190':       ('Datsun 240Z',                            151, 1050, 'T', 4,  8.0, 200, 'classico'),
    'retinue':    ('Ford Escort RS2000 (Mk1)',               100,  900, 'T', 4,  9.0, 175, 'classico'),
    'retinue2':   ('Ford Escort RS2000 (Mk2)',               110,  930, 'T', 4,  8.9, 180, 'classico'),
    'deluxo':     ('DeLorean DMC-12',                        132, 1230, 'T', 5, 10.5, 175, 'classico'),
    'cheburek':   ('Lada 2107 1.5',                           77, 1030, 'T', 5, 15.0, 150, 'popular'),
    'michelli':   ('Lancia Fulvia Coupé HF',                 115,  960, 'D', 5, 10.5, 175, 'classico'),
    'zion3':      ('BMW 635 CSi (E24)',                      218, 1480, 'T', 5,  8.0, 225, 'classico'),
    'ardent':     ('Lotus Esprit S1',                        160,  900, 'T', 5,  8.0, 210, 'classico'),
    'itali2':     ('Ferrari 308 GTB',                        255, 1090, 'T', 5,  6.7, 255, 'classico'),
    # ------------------------------------------------------------ SUV
    'baller':     ('Range Rover Sport 4.2 SC (2005)',        390, 2570, '4x4', 6, 7.6, 225, 'suv'),
    'baller3':    ('Range Rover Sport 5.0 V8 (2014)',        510, 2310, '4x4', 6, 5.3, 250, 'suv'),
    'baller7':    ('Range Rover P530 (2022)',                530, 2585, '4x4', 6, 4.6, 250, 'suv'),
    'granger':    ('Chevrolet Suburban 5.3 V8',              320, 2600, '4x4', 6, 8.4, 180, 'suv'),
    'cavalcade':  ('Cadillac Escalade (2002)',               345, 2600, '4x4', 4, 8.0, 175, 'suv'),
    'cavalcade3': ('Cadillac Escalade (2021)',               420, 2700, '4x4', 6, 6.0, 200, 'suv'),
    'dubsta':     ('Mercedes-Benz G 55 AMG',                 507, 2550, '4x4', 6, 5.5, 210, 'suv'),
    'fq2':        ('Infiniti FX35',                          280, 1950, '4x4', 5, 7.0, 230, 'suv'),
    'gresley':    ('Jeep Grand Cherokee 3.6 (2011)',         290, 2100, '4x4', 6, 8.0, 210, 'suv'),
    'habanero':   ('Lexus RX 350',                           277, 1950, '4x4', 6, 7.8, 200, 'suv'),
    'huntley':    ('Bentley Bentayga W12',                   608, 2440, '4x4', 6, 4.1, 301, 'suv'),
    'landstalker':('Lincoln Navigator (2003)',               300, 2600, '4x4', 6, 9.0, 180, 'suv'),
    'mesa':       ('Jeep Wrangler 3.6',                      285, 1950, '4x4', 5, 7.0, 180, 'offroad'),
    'patriot':    ('Hummer H2 6.0 V8',                       325, 2900, '4x4', 4, 9.5, 160, 'offroad'),
    'rocoto':     ('Audi Q7 3.0 TDI',                        272, 2150, '4x4', 6, 6.3, 234, 'suv'),
    'seminole':   ('Jeep Grand Cherokee 5.2 V8 (ZJ)',        220, 1800, '4x4', 4, 9.5, 180, 'suv'),
    'toros':      ('Lamborghini Urus',                       650, 2200, '4x4', 6, 3.6, 305, 'super'),
    'rebla':      ('BMW X5 M (2019)',                        625, 2310, '4x4', 6, 3.8, 290, 'esportivo'),
    'novak':      ('Maserati Levante S',                     430, 2109, '4x4', 6, 5.2, 264, 'suv'),
    'contender':  ('Ford F-150 Raptor 6.2 (2012)',           411, 2700, '4x4', 6, 7.6, 180, 'offroad'),
    # ------------------------------------------------------------ FORA DE ESTRADA
    'bfinjection':('Buggy VW (Meyers Manx 1.6)',             60,  590, 'T', 4, 12.0, 140, 'offroad'),
    'rebel2':     ('Toyota Hilux 3.0 (anos 90)',            125, 1600, '4x4', 5, 13.5, 160, 'offroad'),
    'dubsta3':    ('Mercedes-AMG G 63 6x6',                 544, 3850, '4x4', 6, 7.4, 160, 'offroad'),
    'caracara2':  ('Ford F-150 Raptor (2017)',              450, 2600, '4x4', 6, 5.9, 172, 'offroad'),
    'everon':     ('Toyota Hilux 2.8 (2016)',               204, 2100, '4x4', 6, 10.0, 175, 'offroad'),
    # ------------------------------------------------------------ VANS
    'minivan':    ('Dodge Grand Caravan 3.3 V6',            180, 1900, 'D', 4, 11.0, 180, 'van'),
    'burrito':    ('Ford Econoline 5.4 V8',                 255, 2500, 'T', 4, 12.0, 160, 'van'),
    'surfer':     ('Volkswagen Kombi 1.6 (Brasil)',          58, 1200, 'T', 4, None, 120, 'van', 9.0),
}

# Faixa realista por classe do GTA para os carros sem ficha:
# classe: (0-100 do mais rápido, 0-100 do mais lento, vmax menor, vmax maior, pneu)
FAIXAS = {
    0:  (9.0, 15.0, 150, 200, 'popular'),
    1:  (7.0, 13.5, 170, 240, 'medio'),
    2:  (6.5, 12.5, 165, 240, 'suv'),
    3:  (5.0,  8.5, 220, 280, 'medio'),
    4:  (4.5,  9.0, 190, 270, 'muscle'),
    5:  (5.0, 11.0, 180, 270, 'classico'),
    6:  (3.4,  6.5, 240, 315, 'esportivo'),
    7:  (2.5,  3.6, 320, 380, 'super'),
    9:  (6.5, 14.0, 140, 190, 'offroad'),
    12: (11.0, 18.0, 135, 170, 'van'),
}

# Fica de fora (armados, arena, drift de fábrica, carros que voam/pulam, RC)
FORA_PALAVRAS = ('Apocalypse', 'Future Shock', 'Nightmare', 'Weaponized', 'Turreted')
FORA_MODELOS = {
    'dilettante2', 'issi4', 'issi5', 'issi6', 'jb7002', 'ruiner2', 'vigilante', 'scramjet',
    'voltic2', 'ignus2', 'tampa3', 'boxville5', 'limo2', 'insurgent', 'insurgent2', 'insurgent3',
    'technical', 'technical3', 'nightshark', 'menacer', 'rcbandito', 'dune2', 'dune3', 'dune4',
    'dune5', 'monster', 'kuruma2_x', 'zr380', 'zr3802', 'zr3803', 'dukes2', 'blista3', 'dominator2',
    'stalion2', 'buffalo3', 'speedo2', 'stretch_x',
}


def fora(v):
    if v['n'] in FORA_MODELOS or v['n'].startswith('drift'):
        return True
    if v['h'].lower().startswith('drift'):
        return True
    return any(p in v['dn'] for p in FORA_PALAVRAS)


def percentil(valor, lista):
    lista = sorted(lista)
    if len(lista) < 2:
        return 0.5
    abaixo = sum(1 for x in lista if x < valor)
    iguais = sum(1 for x in lista if x == valor)
    return (abaixo + (iguais - 1) / 2) / (len(lista) - 1)


def lua_str(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'") + "'"


def main():
    vanilla = json.load(open(os.path.join(AQUI, 'vanilla.json'), encoding='utf-8'))
    por_modelo = {v['n']: v for v in vanilla}
    validos = [v for v in vanilla if not fora(v)]

    # agrupa por handling (alguns modelos dividem a mesma handling)
    grupos = {}
    for v in validos:
        grupos.setdefault(v['h'], []).append(v)

    por_classe = {}
    for h, vs in grupos.items():
        por_classe.setdefault(vs[0]['c'], []).append(h)

    entradas = {}
    erros = []
    # 1) fichas escritas à mão
    for modelo, f in F.items():
        v = por_modelo.get(modelo)
        if not v:
            erros.append('modelo não existe: ' + modelo)
            continue
        h = v['h']
        if h in entradas:
            erros.append('handling repetida %s (%s e %s)' % (h, entradas[h]['de'], modelo))
            continue
        real, cv, kg, tr, marchas, z100, vmax, pneu = f[:8]
        e = dict(de=modelo, real=real, cv=cv, kg=kg, tracao=tr, marchas=marchas,
                 zero100=z100, vmax=vmax, pneu=pneu, classe=v['c'])
        if z100 is None:
            e['zero60'] = f[8]
        entradas[h] = e

    # 2) automáticas: posição dentro da classe (aceleração e velocidade originais)
    for c, hs in por_classe.items():
        if c not in FAIXAS:
            continue
        rapido, lento, vlo, vhi, pneu = FAIXAS[c]
        accs = [sum(x['a'] for x in grupos[h]) / len(grupos[h]) for h in hs]
        vels = [sum(x['s'] for x in grupos[h]) / len(grupos[h]) for h in hs]
        for h, a, s in zip(hs, accs, vels):
            if h in entradas:
                continue
            pa, pv = percentil(a, accs), percentil(s, vels)
            entradas[h] = dict(de=grupos[h][0]['n'], real=None, auto=True, classe=c, pneu=pneu,
                               zero100=round(lento - pa * (lento - rapido), 1),
                               vmax=int(round(vlo + pv * (vhi - vlo))))

    # modelos de cada handling
    modelos = {}
    for v in validos:
        if v['h'] in entradas:
            modelos.setdefault(v['h'], []).append(v['n'])

    linhas = [
        '-- GERADO por tools/gerar_nativos.py. Não edite aqui: mude a ficha no gerador',
        '-- ou sobrescreva no config.lua (Config.fichas).',
        '-- real = carro de inspiração | cv, kg | tração D/T/4x4 | marchas (nil = a do GTA)',
        '-- zero100 (s) | vmax (km/h) | pneu = faixa de pneu e freio (Config.pneus)',
        '-- auto = sem ficha: posição original dentro da classe, na faixa realista',
        'Nativos = {',
    ]
    for h in sorted(entradas, key=lambda h: (entradas[h]['classe'], h)):
        e = entradas[h]
        campos = ['modelos = {%s}' % ', '.join(lua_str(m) for m in sorted(modelos.get(h, [e['de']])))]
        if e.get('real'):
            campos.append('real = ' + lua_str(e['real']))
            campos.append('cv = %d, kg = %d, tracao = %s' % (e['cv'], e['kg'], lua_str(e['tracao'])))
            if e['marchas']:
                campos.append('marchas = %d' % e['marchas'])
        if e.get('auto'):
            campos.append('auto = true')
        if e.get('zero100') is not None:
            campos.append('zero100 = %s' % e['zero100'])
        if e.get('zero60') is not None:
            campos.append('zero60 = %s' % e['zero60'])
        campos.append('vmax = %d' % e['vmax'])
        campos.append('pneu = ' + lua_str(e['pneu']))
        campos.append('classe = %d' % e['classe'])
        linhas.append('    [%s] = { %s },' % (lua_str(h), ', '.join(campos)))
    linhas.append('}')

    destino = os.path.join(AQUI, '..', 'data', 'nativos.lua')
    with open(destino, 'w', encoding='utf-8', newline='\n') as arq:
        arq.write('\n'.join(linhas) + '\n')

    manuais = sum(1 for e in entradas.values() if e.get('real'))
    print('fichas reais: %d | automáticas: %d | total: %d' % (manuais, len(entradas) - manuais, len(entradas)))
    for e in erros:
        print('AVISO:', e)


if __name__ == '__main__':
    main()
