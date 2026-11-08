#!/usr/bin/env python3
"""Writes AppStore/Localization/*.md and checks every field against App Store Connect limits."""
import os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "AppStore", "Localization")
LIMITS = {"name": 30, "subtitle": 30, "promo": 170, "description": 4000}
KEYWORD_BYTES = 100

L = []

L.append(dict(code="en-GB", lang="English (U.K.)",
name="Punch Mine: Idle Mining Game",
subtitle="Tap, Smash Rocks & Find Loot",
promo="New zone: Sunken Ruins! Ride the high tide for ×2.5 rewards, break runestones that hit a whole row, and dig up Pearls and new relics.",
keywords="clicker,tapper,tycoon,dig,digger,ore,gold,gems,incremental,prestige,chest,cave,offline,miner,pickaxe",
description="""Punch rocks. Hire miners. Dig deeper.

Punch Mine is an idle mining game you play with your fists. Tap blocks to smash them, collect ore and coins, and build a crew that keeps digging even when you put your phone down.

SMASH YOUR WAY DOWN
• Every block fights back: iron armour, crystal chains, regrowing magma and the rising tide
• Land critical hits, pierce armour and grow from pebble puncher to titan
• Find hidden treasure and chests as you go deeper

FOUR ZONES TO CONQUER
• Pebble Quarry, Crystal Caverns, Magma Depths and Sunken Ruins
• Each zone has its own currency, tools, music and a Heart waiting at the bottom
• Unlock the next zone and keep earning in all of them

GEAR UP
• 42 items across 5 rarities, from Common to Mythic
• Open Wooden, Iron and Golden chests
• Complete item sets, roll bonus stats and salvage what you don't need

GET STRONGER EVERY RUN
• Prestige to earn Perk Coins and unlock 25 perks across Power, Industry and Exploration
• Ascend for Star Perks and even bigger boosts
• Auto-prestige once you've earned it

PLAY YOUR WAY
• Your miners keep working while you're away (up to 4 hours)
• Daily rewards and lifetime stats
• iCloud backup keeps your mine safe across your devices
• Short sessions or long ones, it all counts

Punch Mine is free to play. Optional in-app purchases are available, and optional ads give you bonuses like Coin Rush or double earnings. The Remove Ads purchase removes the ads between runs."""))

L.append(dict(code="ro", lang="Romanian",
name="Punch Mine: Minerit Idle",
subtitle="Sparge pietre, găsește comori",
promo="Zonă nouă: Sunken Ruins! Prinde fluxul pentru recompense ×2,5, sparge pietre runice care lovesc tot rândul și adună perle și relicve noi.",
keywords="clicker,miner,mina,sapat,aur,minereu,diamante,cufar,pestera,prestigiu,offline,tycoon,tapper,cristale",
description="""Lovește pietrele. Angajează mineri. Sapă mai adânc.

Punch Mine este un joc idle de minerit în care sapi cu pumnii. Atinge blocurile ca să le spargi, adună minereu și monede și construiește o echipă care sapă mai departe chiar și când lași telefonul jos.

SPARGE-ȚI DRUMUL ÎN ADÂNC
• Fiecare bloc se apără: armură de fier, lanțuri de cristale, magmă care crește la loc și fluxul care urcă
• Dă lovituri critice, străpunge armura și ajungi de la spărgător de pietricele la titan
• Găsește comori ascunse și cufere pe măsură ce cobori

PATRU ZONE DE CUCERIT
• Pebble Quarry, Crystal Caverns, Magma Depths și Sunken Ruins
• Fiecare zonă are moneda, uneltele și muzica ei, plus o Inimă care te așteaptă la fund
• Deblochează zona următoare și câștigă în continuare în toate

ECHIPEAZĂ-TE
• 42 de obiecte în 5 rarități, de la Common la Mythic
• Deschide cufere de lemn, de fier și de aur
• Completează seturi, obține bonusuri aleatorii și reciclează ce nu-ți trebuie

MAI PUTERNIC LA FIECARE TURĂ
• Fă prestigiu ca să câștigi Perk Coins și deblochează 25 de abilități în Power, Industry și Exploration
• Ascensiunea îți aduce Star Perks și bonusuri și mai mari
• Prestigiu automat, după ce îl meriți

JOACĂ CUM VREI
• Minerii tăi muncesc și cât lipsești (până la 4 ore)
• Recompense zilnice și statistici
• Backup în iCloud, ca mina ta să fie în siguranță pe toate dispozitivele
• Sesiuni scurte sau lungi, totul contează

Punch Mine este gratuit. Sunt disponibile achiziții opționale în aplicație, iar reclamele opționale îți dau bonusuri precum Coin Rush sau câștiguri duble. Achiziția Remove Ads elimină reclamele dintre ture."""))

L.append(dict(code="de-DE", lang="German",
name="Punch Mine: Idle-Bergbauspiel",
subtitle="Steine knacken, Schätze finden",
promo="Neue Zone: Sunken Ruins! Nutze die Flut für ×2,5 Belohnungen, zerschlage Runensteine, die eine ganze Reihe treffen, und sammle Perlen und neue Relikte.",
keywords="clicker,tapper,tycoon,bergwerk,gold,erz,edelsteine,graben,truhe,höhle,offline,prestige,spitzhacke",
description="""Schlag zu. Heuere Bergleute an. Grab tiefer.

Punch Mine ist ein Idle-Bergbauspiel, das du mit den Fäusten spielst. Tippe auf Blöcke, um sie zu zerschlagen, sammle Erz und Münzen und baue eine Crew auf, die weitergräbt, auch wenn du das Handy weglegst.

SCHLAG DICH NACH UNTEN DURCH
• Jeder Block wehrt sich: Eisenpanzer, Kristallketten, nachwachsendes Magma und die steigende Flut
• Lande kritische Treffer, durchbrich Panzerung und werde vom Kieselklopfer zum Titanen
• Finde versteckte Schätze und Truhen, je tiefer du kommst

VIER ZONEN ZUM EROBERN
• Pebble Quarry, Crystal Caverns, Magma Depths und Sunken Ruins
• Jede Zone hat ihre eigene Währung, Werkzeuge, Musik und ein Herz, das ganz unten wartet
• Schalte die nächste Zone frei und verdiene in allen weiter

RÜSTE DICH AUS
• 42 Gegenstände in 5 Seltenheitsstufen, von Common bis Mythic
• Öffne Holz-, Eisen- und Goldtruhen
• Vervollständige Sets, erhalte Bonuswerte und zerlege, was du nicht brauchst

JEDE RUNDE STÄRKER
• Mit Prestige verdienst du Perk Coins und schaltest 25 Perks in Power, Industry und Exploration frei
• Steige auf für Star Perks und noch größere Boni
• Automatisches Prestige, sobald du es dir verdient hast

SPIEL, WIE DU WILLST
• Deine Bergleute arbeiten weiter, während du weg bist (bis zu 4 Stunden)
• Tägliche Belohnungen und Statistiken
• Das iCloud-Backup schützt deine Mine auf all deinen Geräten
• Kurze oder lange Runden – alles bringt dich voran

Punch Mine ist kostenlos spielbar. Optionale In-App-Käufe sind verfügbar, und optionale Werbung gibt dir Boni wie Coin Rush oder doppelte Einnahmen. Der Kauf „Remove Ads“ entfernt die Werbung zwischen den Runden."""))

L.append(dict(code="fr-FR", lang="French",
name="Punch Mine : Jeu de mine idle",
subtitle="Frappe, creuse, trouve l'or",
promo="Nouvelle zone : Sunken Ruins ! Profite de la marée haute pour des gains ×2,5, brise des pierres runiques qui frappent toute une rangée et récolte perles et reliques.",
keywords="clicker,tycoon,mineur,minerai,pioche,gemmes,coffre,grotte,prestige,incrémental,trésor,hors ligne",
description="""Frappe. Recrute. Creuse plus profond.

Punch Mine est un jeu de mine idle qui se joue à mains nues. Touche les blocs pour les briser, ramasse du minerai et des pièces, et monte une équipe qui continue de creuser même quand tu poses ton téléphone.

FRAYE-TOI UN CHEMIN VERS LES PROFONDEURS
• Chaque bloc résiste : armure de fer, chaînes de cristaux, magma qui repousse et marée montante
• Place des coups critiques, perce les armures et passe de casseur de cailloux à titan
• Découvre des trésors cachés et des coffres en descendant

QUATRE ZONES À CONQUÉRIR
• Pebble Quarry, Crystal Caverns, Magma Depths et Sunken Ruins
• Chaque zone a sa monnaie, ses outils, sa musique et un Cœur qui t'attend tout au fond
• Débloque la zone suivante et continue de gagner dans toutes

ÉQUIPE-TOI
• 42 objets répartis en 5 raretés, de Common à Mythic
• Ouvre des coffres en bois, en fer et en or
• Complète des sets, obtiens des bonus aléatoires et recycle ce dont tu n'as pas besoin

PLUS FORT À CHAQUE PARTIE
• Fais un prestige pour gagner des Perk Coins et débloquer 25 atouts dans Power, Industry et Exploration
• L'Ascension t'offre des Star Perks et des bonus encore plus grands
• Prestige automatique une fois mérité

JOUE COMME TU VEUX
• Tes mineurs travaillent pendant ton absence (jusqu'à 4 heures)
• Récompenses quotidiennes et statistiques
• La sauvegarde iCloud protège ta mine sur tous tes appareils
• Sessions courtes ou longues : tout compte

Punch Mine est gratuit. Des achats intégrés facultatifs sont disponibles, et des publicités facultatives offrent des bonus comme Coin Rush ou des gains doublés. L'achat Remove Ads supprime les publicités entre les parties."""))

ES_DESC = """Golpea rocas. Contrata mineros. Cava más hondo.

Punch Mine es un juego idle de minería que juegas a puñetazos. Toca los bloques para romperlos, recoge mineral y monedas, y forma un equipo que sigue cavando incluso cuando dejas el {phone}.

ABRE CAMINO HACIA EL FONDO
• Cada bloque se defiende: armadura de hierro, cadenas de cristales, magma que vuelve a crecer y la marea que sube
• Asesta golpes críticos, atraviesa armaduras y pasa de romper guijarros a ser un titán
• Encuentra tesoros ocultos y cofres a medida que bajas

CUATRO ZONAS POR CONQUISTAR
• Pebble Quarry, Crystal Caverns, Magma Depths y Sunken Ruins
• Cada zona tiene su propia moneda, herramientas, música y un Corazón que te espera en el fondo
• Desbloquea la siguiente zona y sigue ganando en todas

EQUÍPATE
• 42 objetos en 5 rarezas, de Common a Mythic
• Abre cofres de madera, hierro y oro
• Completa conjuntos, consigue bonificaciones aleatorias y recicla lo que no necesites

MÁS FUERTE EN CADA PARTIDA
• Haz prestigio para ganar Perk Coins y desbloquea 25 ventajas en Power, Industry y Exploration
• Asciende para conseguir Star Perks y bonificaciones aún mayores
• Prestigio automático cuando te lo ganes

JUEGA A TU MANERA
• Tus mineros siguen trabajando mientras no estás (hasta 4 horas)
• Recompensas diarias y estadísticas
• Copia de seguridad en iCloud para proteger tu mina en todos tus dispositivos
• Partidas cortas o largas: todo suma

Punch Mine es gratis. Hay compras opcionales dentro de la app, y los anuncios opcionales te dan bonificaciones como Coin Rush o ganancias dobles. La compra Remove Ads quita los anuncios entre partidas."""
ES_PROMO = "¡Nueva zona: Sunken Ruins! Aprovecha la marea alta para ganar ×2,5, rompe piedras rúnicas que golpean toda una fila y consigue perlas y reliquias nuevas."

L.append(dict(code="es-MX", lang="Spanish (Mexico)",
name="Punch Mine: Minería Idle",
subtitle="Golpea rocas y encuentra botín",
promo=ES_PROMO,
keywords="minar,excavar,picar,diamantes,tesoros,cofres,cuevas,magma,ruinas,cristales,monedas,inactivo,clic",
description=ES_DESC.format(phone="celular"),
note="The U.S. App Store also searches the Spanish (Mexico) keywords, so this list avoids the English words already used in en-GB and reaches more searches in the U.S. too."))

L.append(dict(code="pt-BR", lang="Portuguese (Brazil)",
name="Punch Mine: Mineração Idle",
subtitle="Quebre pedras e ache tesouros",
promo="Nova zona: Sunken Ruins! Aproveite a maré alta para ganhar ×2,5, quebre pedras rúnicas que atingem a fileira inteira e colete pérolas e relíquias novas.",
keywords="clicker,tapper,tycoon,minerador,mina,cavar,ouro,minério,gemas,baú,caverna,prestígio,incremental",
description="""Soque pedras. Contrate mineradores. Cave mais fundo.

Punch Mine é um jogo idle de mineração que você joga no soco. Toque nos blocos para quebrá-los, junte minério e moedas e monte uma equipe que continua cavando mesmo quando você larga o celular.

ABRA CAMINHO ATÉ O FUNDO
• Cada bloco revida: armadura de ferro, correntes de cristais, magma que volta a crescer e a maré que sobe
• Acerte golpes críticos, perfure armaduras e passe de quebrador de pedrinhas a titã
• Encontre tesouros escondidos e baús enquanto desce

QUATRO ZONAS PARA CONQUISTAR
• Pebble Quarry, Crystal Caverns, Magma Depths e Sunken Ruins
• Cada zona tem sua própria moeda, ferramentas, música e um Coração esperando lá no fundo
• Desbloqueie a próxima zona e continue ganhando em todas

EQUIPE-SE
• 42 itens em 5 raridades, de Common a Mythic
• Abra baús de madeira, ferro e ouro
• Complete conjuntos, ganhe bônus aleatórios e recicle o que não precisar

MAIS FORTE A CADA PARTIDA
• Faça prestígio para ganhar Perk Coins e desbloquear 25 vantagens em Power, Industry e Exploration
• Ascenda para ganhar Star Perks e bônus ainda maiores
• Prestígio automático quando você merecer

JOGUE DO SEU JEITO
• Seus mineradores trabalham enquanto você está fora (até 4 horas)
• Recompensas diárias e estatísticas
• Backup no iCloud protege sua mina em todos os seus aparelhos
• Sessões curtas ou longas: tudo é progresso

Punch Mine é gratuito. Há compras opcionais no app, e anúncios opcionais dão bônus como Coin Rush ou ganhos em dobro. A compra Remove Ads remove os anúncios entre as partidas."""))

L.append(dict(code="zh-Hans", lang="Chinese (Simplified)",
name="Punch Mine：放置挖矿游戏",
subtitle="点击碎石，挖矿寻宝",
promo="新区域：Sunken Ruins！趁着涨潮获得 ×2.5 奖励，击碎能打击整行的符文石，收集珍珠和全新遗物。",
keywords="挂机,矿工,点击,采矿,宝石,宝箱,金币,矿石,洞穴,离线,转生,镐子,寻宝,增量",
note="Games with in-app purchases need a Chinese ISBN approval number to be sold in mainland China. Without one, leave China mainland out of Availability; this copy still serves Singapore, Malaysia and other Simplified Chinese storefronts.",
description="""出拳碎石。雇佣矿工。越挖越深。

Punch Mine 是一款用拳头玩的放置挖矿游戏。点击方块将其击碎，收集矿石和金币，组建一支即使你放下手机也会继续挖掘的矿工队伍。

一路向下猛击
• 每个方块都会反击：铁甲、水晶锁链、会再生的岩浆，还有不断上涨的潮水
• 打出暴击，击穿护甲，从碎石小拳手成长为泰坦
• 越往深处挖，越能找到隐藏的宝藏和宝箱

四大区域等你征服
• Pebble Quarry、Crystal Caverns、Magma Depths 和 Sunken Ruins
• 每个区域都有独特的货币、工具、音乐，以及在最底部等待你的心脏
• 解锁下一个区域，同时在所有区域持续获得收益

装备升级
• 42 件物品，分为 5 种稀有度，从 Common 到 Mythic
• 开启木制、铁制和黄金宝箱
• 集齐套装，随机获得额外属性，分解不需要的物品

每一轮都更强
• 转生获得 Perk Coins，在 Power、Industry 和 Exploration 中解锁 25 项天赋
• 飞升获得 Star Perks 和更强大的加成
• 达成条件后可自动转生

随心畅玩
• 离开期间矿工也会继续工作（最长 4 小时）
• 每日奖励与生涯统计
• iCloud 备份让你的矿场在所有设备上安全无忧
• 无论玩得长短，每一刻都算数

Punch Mine 可免费游玩。游戏提供可选的 App 内购买项目，观看可选广告可获得 Coin Rush 或双倍收益等加成。购买 Remove Ads 可移除每轮之间的广告。"""))

L.append(dict(code="ja", lang="Japanese",
name="Punch Mine: 放置系採掘ゲーム",
subtitle="タップで岩を砕いてお宝探し",
promo="新ゾーン「Sunken Ruins」登場！満潮で報酬×2.5、列ごと攻撃するルーンストーンを砕き、真珠や新しいレリックを手に入れよう。",
keywords="クリッカー,タップ,鉱山,ピッケル,宝石,宝箱,洞窟,オフライン,転生,金貨",
description="""岩を殴れ。鉱夫を雇え。もっと深く掘れ。

Punch Mine は、こぶしで遊ぶ放置系採掘ゲームです。ブロックをタップして砕き、鉱石とコインを集めて、スマホを置いている間も掘り続けてくれるチームを育てましょう。

殴って掘り進め
• どのブロックも手ごわい：鉄の装甲、クリスタルの鎖、再生するマグマ、そして満ちてくる潮
• クリティカルを決め、装甲を貫き、小石割りからタイタンへと成長しよう
• 深く進むほど、隠されたお宝や宝箱が見つかる

4つのゾーンを制覇
• Pebble Quarry、Crystal Caverns、Magma Depths、Sunken Ruins
• ゾーンごとに専用の通貨、道具、音楽があり、最深部には「ハート」が待っている
• 次のゾーンを解放して、すべてのゾーンで稼ぎ続けよう

装備を整えよう
• Common から Mythic まで、5つのレアリティに42種類のアイテム
• 木の宝箱、鉄の宝箱、金の宝箱を開けよう
• セットをそろえ、ボーナス能力を引き当て、いらないものは分解

周回するたびに強くなる
• 転生で Perk Coins を獲得し、Power、Industry、Exploration の25種類のパークを解放
• アセンションで Star Perks とさらに大きなボーナスを獲得
• 条件を満たせば自動転生も可能

自分のペースで遊べる
• 留守の間も鉱夫たちが働き続ける（最大4時間）
• デイリー報酬と累計記録
• iCloud バックアップで、どのデバイスでも鉱山を安全に保存
• 短い時間でも長い時間でも、すべてが前進につながる

Punch Mine は基本プレイ無料です。任意のアプリ内課金があり、任意の広告を見ると Coin Rush や獲得量2倍などのボーナスがもらえます。「Remove Ads」を購入すると、周回の合間の広告が表示されなくなります。"""))

L.append(dict(code="ko", lang="Korean",
name="Punch Mine: 방치형 채굴 게임",
subtitle="탭해서 바위 깨고 보물 찾기",
promo="새 구역 Sunken Ruins! 만조를 타고 ×2.5 보상을 얻고, 한 줄 전체를 공격하는 룬석을 부수고, 진주와 새 유물을 모으세요.",
keywords="클리커,광산,광부,곡괭이,보석,상자,동굴,오프라인,환생,타이쿤,보물",
description="""바위를 쳐라. 광부를 고용하라. 더 깊이 파라.

Punch Mine은 주먹으로 즐기는 방치형 채굴 게임입니다. 블록을 탭해 부수고, 광석과 코인을 모으고, 휴대폰을 내려놓아도 계속 땅을 파는 광부 팀을 키워 보세요.

부수며 내려가라
• 모든 블록이 저항합니다: 철 갑옷, 크리스털 사슬, 다시 자라나는 마그마, 차오르는 물결
• 치명타를 터뜨리고, 갑옷을 관통하며, 조약돌 펀처에서 타이탄으로 성장하세요
• 깊이 내려갈수록 숨겨진 보물과 상자를 발견할 수 있습니다

정복할 4개의 구역
• Pebble Quarry, Crystal Caverns, Magma Depths, Sunken Ruins
• 구역마다 고유한 화폐, 도구, 음악이 있고, 가장 깊은 곳에는 하트가 기다립니다
• 다음 구역을 열고 모든 구역에서 계속 수익을 올리세요

장비를 갖춰라
• Common부터 Mythic까지 5가지 등급, 42개의 아이템
• 나무, 철, 황금 상자 열기
• 세트를 완성하고, 보너스 능력치를 얻고, 필요 없는 아이템은 분해하세요

매 판마다 더 강하게
• 환생으로 Perk Coins를 얻고 Power, Industry, Exploration에서 25개의 퍽을 해금하세요
• 승천으로 Star Perks와 더 큰 보너스를 얻으세요
• 조건을 달성하면 자동 환생 가능

원하는 방식으로 플레이
• 자리를 비운 동안에도 광부들이 계속 일합니다 (최대 4시간)
• 일일 보상과 누적 통계
• iCloud 백업으로 모든 기기에서 광산을 안전하게 보관
• 짧게 하든 길게 하든, 모든 플레이가 성장으로 이어집니다

Punch Mine은 무료로 플레이할 수 있습니다. 선택적인 앱 내 구입이 있으며, 선택형 광고를 보면 Coin Rush나 수익 2배 같은 보너스를 받을 수 있습니다. Remove Ads를 구입하면 판 사이의 광고가 제거됩니다."""))

ALT_NAMES = {'en-GB': ['Punch Mine: Tap & Dig', 'Punch Mine: Idle Clicker Miner', 'Punch Mine: Rock Smash Idle', 'Punch Mine: Dig Deep Tycoon', 'Punch Mine: Mining Clicker'], 'ro': ['Punch Mine: Minerul Idle', 'Punch Mine: Sapă și Câștigă', 'Punch Mine: Joc Minerit Idle', 'Punch Mine: Sparge Pietre', 'Punch Mine: Mina Clicker'], 'de-DE': ['Punch Mine: Bergbau Clicker', 'Punch Mine: Idle Minen-Tycoon', 'Punch Mine: Tippen & Graben', 'Punch Mine: Steine Knacken', 'Punch Mine: Idle-Bergwerk'], 'fr-FR': ['Punch Mine : Mineur Idle', 'Punch Mine : Clicker de Mine', 'Punch Mine : Tape et Creuse', 'Punch Mine : Casse-Cailloux', 'Punch Mine : Tycoon de Mine'], 'es-MX': ['Punch Mine: Mina Idle', 'Punch Mine: Pica y Mina', 'Punch Mine: Clicker Minero', 'Punch Mine: Rompe Piedras', 'Punch Mine: Excava y Gana'], 'pt-BR': ['Punch Mine: Minerador Idle', 'Punch Mine: Clicker de Mina', 'Punch Mine: Toque e Cave', 'Punch Mine: Quebra Pedras', 'Punch Mine: Magnata da Mina'], 'zh-Hans': ['Punch Mine：挖矿大亨', 'Punch Mine：点击挖矿', 'Punch Mine：碎石寻宝', 'Punch Mine：放置矿工', 'Punch Mine：深层挖掘'], 'ja': ['Punch Mine: タップで採掘', 'Punch Mine: 放置マイナー', 'Punch Mine: 岩砕きクリッカー', 'Punch Mine: 鉱山タイクーン', 'Punch Mine: 掘って掘って'], 'ko': ['Punch Mine: 탭 앤 디그', 'Punch Mine: 방치형 광부', 'Punch Mine: 바위 부수기', 'Punch Mine: 광산 타이쿤', 'Punch Mine: 클리커 채굴']}

os.makedirs(OUT, exist_ok=True)
ok = True
rows = []
for loc in L:
    counts = {k: len(loc[k]) for k in LIMITS}
    kb = len(loc["keywords"].encode("utf-8"))
    bad = [k for k in LIMITS if counts[k] > LIMITS[k]] + (["keywords"] if kb > KEYWORD_BYTES else [])
    bad += [f"alt:{n}" for n in ALT_NAMES[loc["code"]] if len(n) > 30]
    if ", " in loc["keywords"] or loc["keywords"].endswith(","):
        bad.append("keywords-format")
    ok &= not bad
    rows.append((loc["code"], counts["name"], counts["subtitle"], counts["promo"], kb, counts["description"], bad))

    def block(title, key, limit, unit="characters", value=None):
        v = loc[key]
        n = value if value is not None else len(v)
        return f"## {title}\n{n} / {limit} {unit}\n\n```\n{v}\n```\n"

    parts = [f"# Punch Mine: {loc['lang']} (`{loc['code']}`)\n"]
    if loc.get("note"):
        parts.append(f"> {loc['note']}\n")
    parts += [
        block("App Name", "name", 30),
        "## App Name alternatives\nUse one if the name above is taken. The name must be unique on the App Store.\n\n"
        + "\n".join(f"{i}. `{n}` ({len(n)} / 30)" for i, n in enumerate(ALT_NAMES[loc["code"]], 1)) + "\n",
        block("Subtitle", "subtitle", 30),
        block("Promotional Text", "promo", 170),
        block("Keywords", "keywords", 100, "bytes", kb),
        block("Description", "description", 4000),
    ]
    with open(os.path.join(OUT, f"{loc['code']}.md"), "w") as f:
        f.write("\n".join(parts))

opts = ["# Punch Mine: App Name Options\n",
    "Alternative App Store names for each language, in case the current one is taken. Every name is 30 characters or fewer (the App Store limit).\n",
    "- Only the **primary language** name (English U.K.) must be unique when you create the app; the others are checked when each language is saved.\n"
    "- If even \"Punch Mine\" alone is taken, every option here will be rejected. Change the brand slightly instead (for example **Punch Mine!**, **PunchMine** or **Punch Mine Idle**).\n"
    "- If the chosen name contains a word that's also in that language's keywords (such as \"Clicker\" or \"Tycoon\"), remove it from the keywords. Words in the name already count for search.\n"]
for loc in L:
    opts.append(f"## {loc['lang']} (`{loc['code']}`)\n\n| # | Name | Length |\n|---|---|---|\n"
        + f"| current | `{loc['name']}` | {len(loc['name'])} / 30 |\n"
        + "".join(f"| {i} | `{n}` | {len(n)} / 30 |\n" for i, n in enumerate(ALT_NAMES[loc["code"]], 1)))
with open(os.path.join(OUT, "App-Name-Options.md"), "w") as f:
    f.write("\n".join(opts))

print(f"{'locale':7} {'name':>5} {'sub':>4} {'promo':>6} {'kwB':>4} {'desc':>5}  problems")
for r in rows:
    print(f"{r[0]:7} {r[1]:>5} {r[2]:>4} {r[3]:>6} {r[4]:>4} {r[5]:>5}  {', '.join(r[6]) or 'ok'}")
print("ALL OK" if ok else "SOME FIELDS OVER LIMIT")
