return {
    ['testburger'] = {
        label = 'Test Burger',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Lick it',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Squeeze it',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'What do you call a vegan burger?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'What do frogs like to eat with their hamburgers?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Why were the burger and fries running?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['bandage'] = {
        label = 'Bandage',
        weight = 115,
    },

    ['burger'] = {
        label = 'Burger',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 160,
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['money'] = {
        label = 'Money',
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    ['id_card'] = {
        label = 'Identification Card',
    },

    ['driver_license'] = {
        label = 'Drivers License',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
    },

    ['radio'] = {
        label = 'Radio',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Kit de emergência', weight = 2500, close = true,
        description = 'Conserto rápido de rua: o motor volta a ligar com pouca vida. Leve o carro a uma oficina.',
        client = { export = 'pista_tuning.usarKitEmergencia' },
    },

    ['advancedrepairkit'] = {
        label = 'Kit de reparo avançado', weight = 4000, close = true,
        description = 'Só mecânico: deixa o motor com metade da vida.',
        client = { export = 'pista_tuning.usarKitAvancado', image = 'advancedkit.png' },
    },

    ['diamond_ring'] = {
        label = 'Diamond',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        weight = 100,
    },

    ['meth'] = {
        label = 'Methamphetamine',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'First Aid',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Painkillers',
        weight = 400,
    },

    ['firework1'] = {
        label = '2Brothers',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Rubber',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Aluminium',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Toaster',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'Antipatharia',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Dendrogyra',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Lighter',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        weight = 200,
    },

    ['harness'] = {
        label = 'Harness',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        weight = 200,
    },

    -- ===== Pista & Asfalto: peças de preparação (pista_tuning) =====
    ['peca_turbo'] = {
        label = 'Turbo', weight = 8000, stack = true, close = true,
        description = 'Instalar no elevador. Requer nível 1 de preparação.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['peca_intercooler'] = {
        label = 'Intercooler', weight = 5000, stack = true, close = true,
        description = 'Esfria o ar do turbo. Protege o motor com chip Stage 2+.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['peca_pistao_forjado'] = {
        label = 'Pistão forjado', weight = 3000, stack = true, close = true,
        description = 'Para TURBO: aguenta pressão alta e libera +0.4 bar no remap. Vai no motor aberto na bancada.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['chip_stage1'] = {
        label = 'Chip Stage 1', weight = 200, stack = true, close = true,
        description = 'Remap leve. Requer nível 1.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['chip_stage2'] = {
        label = 'Chip Stage 2', weight = 200, stack = true, close = true,
        description = 'Requer turbo instalado e nível 2. Use com intercooler.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['chip_stage3'] = {
        label = 'Chip Stage 3', weight = 200, stack = true, close = true,
        description = 'Requer turbo e nível 3. Sem pistão forjado o motor quebra.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['kit_nitro'] = {
        label = 'Kit de nitro', weight = 10000, stack = true, close = true,
        description = 'Instala o sistema de nitro. Requer nível 2.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['garrafa_nitro'] = {
        label = 'Garrafa de nitro', weight = 4000, stack = true, close = true,
        description = 'Recarrega o nitro de um carro com kit instalado.',
        client = { export = 'pista_tuning.usarGarrafaNitro' },
    },
    ['manual_motor'] = {
        label = 'Manual técnico: Motor', weight = 400, stack = true, close = true,
        description = 'Dá XP de mecânica uma única vez por personagem.',
        consume = 0,
        client = { export = 'pista_skills.usarManual' },
    },
    ['manual_chassi'] = {
        label = 'Manual técnico: Chassi', weight = 400, stack = true, close = true,
        description = 'Dá XP de mecânica uma única vez por personagem.',
        consume = 0,
        client = { export = 'pista_skills.usarManual' },
    },
    ['manual_eletronica'] = {
        label = 'Manual técnico: Eletrônica', weight = 400, stack = true, close = true,
        description = 'Dá XP de mecânica uma única vez por personagem.',
        consume = 0,
        client = { export = 'pista_skills.usarManual' },
    },
    ['notebook_remap'] = {
        label = 'Notebook de remap', weight = 2500, stack = false, close = true,
        description = 'Conecta na ECU do carro no elevador para ajustar o mapa do chip.',
        client = { export = 'pista_tuning.usarNotebook' },
    },
    ['peca_pistao_taxado'] = {
        label = 'Pistão taxado', weight = 3000, stack = true, close = true,
        description = 'Alta taxa de compressão, para ASPIRADO. Com turbo dá batida de pino. Vai no motor aberto.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['junta_reforcada'] = {
        label = 'Junta de cabeçote reforçada', weight = 500, stack = true, close = true,
        description = 'Junta metálica (MLS). Obrigatória para turbo acima de 1.4 bar. Vai no motor aberto.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['bielas_forjadas'] = {
        label = 'Bielas forjadas', weight = 4000, stack = true, close = true,
        description = 'Liberam o limitador acima de 8.500 rpm e reduzem o risco em giro alto. Vai no motor aberto.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['cabecote_retrabalhado'] = {
        label = 'Cabeçote retrabalhado', weight = 9000, stack = true, close = true,
        description = 'Dutos polidos e válvulas maiores. Melhora qualquer motor e libera +200 rpm no remap.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['cabecote_competicao'] = {
        label = 'Cabeçote de corrida', weight = 9000, stack = true, close = true,
        description = 'Rende muito só com pistão taxado ou forjado. Libera +500 rpm no remap.',
        client = { export = 'pista_tuning.usarPeca' },
    },
    ['freio_rua'] = {
        label = 'Kit de freio de rua', weight = 6000, stack = true, close = true,
        description = 'Pastilhas e discos de rua. Instale nas 4 rodas no elevador.',
        client = { export = 'pista_tuning.usarFreio' },
    },
    ['freio_esportivo'] = {
        label = 'Kit de freio esportivo', weight = 7000, stack = true, close = true,
        description = 'Discos ventilados e pinças esportivas. Instale nas 4 rodas no elevador.',
        client = { export = 'pista_tuning.usarFreio' },
    },
    ['freio_competicao'] = {
        label = 'Kit de freio de competição', weight = 8000, stack = true, close = true,
        description = 'Freio de pista. Instale nas 4 rodas no elevador.',
        client = { export = 'pista_tuning.usarFreio' },
    },
    ['cambio_rua'] = {
        label = 'Transmissão de rua', weight = 15000, stack = true, close = true,
        description = 'Instale com o jogo de soquetes, em qualquer lugar (capô aberto).',
        client = { export = 'pista_tuning.usarCambio' },
    },
    ['cambio_esportivo'] = {
        label = 'Transmissão esportiva', weight = 15000, stack = true, close = true,
        description = 'Engates mais rápidos. Instale com o jogo de soquetes, em qualquer lugar.',
        client = { export = 'pista_tuning.usarCambio' },
    },
    ['cambio_competicao'] = {
        label = 'Transmissão de competição', weight = 15000, stack = true, close = true,
        description = 'Câmbio de pista. Instale com o jogo de soquetes, em qualquer lugar.',
        client = { export = 'pista_tuning.usarCambio' },
    },
    ['suspensao_regulavel'] = {
        label = 'Suspensão regulável', weight = 12000, stack = true, close = true,
        description = 'Kit coilover (rosca). Instale nas 4 rodas no elevador; depois regule com /suspensao.',
        client = { export = 'pista_tuning.usarSuspensao' },
    },
    ['pneu'] = {
        label = 'Pneu', weight = 8000, stack = true, close = true,
        description = 'Mire no pneu furado com o Alt e troque. Precisa do macaco.',
        client = { export = 'pista_tuning.usarPneu' },
    },
    ['macaco'] = {
        label = 'Macaco hidráulico', weight = 5000, stack = false,
        description = 'Levanta o carro para trocar pneu. Desgasta com o uso.',
    },
    ['kit_funilaria'] = {
        label = 'Kit de funilaria', weight = 6000, stack = true, close = true,
        description = 'Só mecânico. Tira amassados e arranhões, troca os vidros e recoloca porta, capô e porta-malas.',
        client = { export = 'pista_tuning.usarFunilaria' },
    },
    ['kit_retifica'] = {
        label = 'Kit de retífica', weight = 10000, stack = true, close = true,
        description = 'Use no motor aberto na bancada. O motor volta novo ao ser recolocado.',
        client = { export = 'pista_tuning.usarRetifica' },
    },
    ['jogo_soquetes'] = {
        label = 'Jogo de soquetes', weight = 3000, stack = false,
        description = 'Catraca e soquetes. Tira e coloca motor e peças externas. Desgasta com o uso.',
    },
    ['torquimetro'] = {
        label = 'Torquímetro', weight = 1500, stack = false,
        description = 'Abre e fecha o motor e monta pistão e cabeçote. Desgasta com o uso.',
    },
}
