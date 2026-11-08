"""Localised App Store art text (screenshots, search results image, header) and the fonts each language needs.

Shot text is (title, subtitle, sticker), in the order of compose.SHOTS. Titles are always two lines split by <br>;
<span> marks the gold words. Text never wraps: anything too wide is shrunk to fit by FIT_JS.
"""

LOCALES = {
    "en-GB": dict(
        shots=[
            ('PUNCH ROCKS.<br><span>GET RICH!</span>', "Tap to smash, hire a crew, dig deeper", "IDLE + TAPPER"),
            ('DEFEAT<br>THE <span>HEART</span>', "A giant boss waits at area 100", "BOSS FIGHT!"),
            ('<span>4+ WORLDS</span><br>TO CONQUER', "Each with its own boss, music and loot", "UNLOCK THEM ALL"),
            ('<span>LEGENDARY</span><br>LOOT', "42+ items, 5 rarities, 3 chest types", "LEGENDARY!"),
            ('<span>25 PERKS</span><br>TO MASTER', "Prestige, ascend, get stronger", "PRESTIGE & ASCEND"),
            ('YOUR CREW<br><span>DIGS FOR YOU</span>', "Miners earn while you're away", "UP TO 4 H AWAY"),
        ],
        search='TAP.<br>SMASH.<br><span>GET RICH!</span>',
        header="Smash. Loot. Conquer."),
    "zh-Hans": dict(
        shots=[
            ('出拳碎石<br><span>一夜暴富！</span>', "点击击碎，雇佣矿工，越挖越深", "放置 + 点击"),
            ('击败<br><span>心脏首领</span>', "巨型首领在第 100 层等你", "首领战！"),
            ('<span>4+ 个世界</span><br>等你征服', "每个世界都有专属首领、音乐和战利品", "全部解锁"),
            ('<span>传说级</span><br>战利品', "42+ 件物品，5 种稀有度，3 种宝箱", "传说！"),
            ('<span>25 项天赋</span><br>等你精通', "转生、飞升，越来越强", "转生与飞升"),
            ('矿工队伍<br><span>替你挖矿</span>', "你不在时矿工也在赚钱", "离线最长 4 小时"),
        ],
        search='点击！<br>碎石！<br><span>暴富！</span>',
        header="碎石 · 夺宝 · 征服"),
    "fr-FR": dict(
        shots=[
            ('FRAPPE LES ROCS.<br><span>DEVIENS RICHE !</span>', "Frappe, recrute, creuse plus profond", "IDLE + TAPPER"),
            ('BATS<br>LE <span>CŒUR</span>', "Un boss géant t'attend au niveau 100", "COMBAT DE BOSS !"),
            ('<span>4+ MONDES</span><br>À CONQUÉRIR', "Chacun avec son boss, sa musique et son butin", "DÉBLOQUE-LES TOUS"),
            ('BUTIN<br><span>LÉGENDAIRE</span>', "42+ objets, 5 raretés, 3 types de coffres", "LÉGENDAIRE !"),
            ('<span>25 ATOUTS</span><br>À MAÎTRISER', "Prestige, Ascension, toujours plus fort", "PRESTIGE & ASCENSION"),
            ('TON ÉQUIPE<br><span>CREUSE POUR TOI</span>', "Tes mineurs gagnent pendant ton absence", "JUSQU'À 4 H"),
        ],
        search='TAPE.<br>CASSE.<br><span>DEVIENS RICHE !</span>',
        header="Frappe. Pille. Conquiers."),
    "de-DE": dict(
        shots=[
            ('SCHLAG ZU.<br><span>WERD REICH!</span>', "Tippen, Crew anheuern, tiefer graben", "IDLE + TAPPER"),
            ('BESIEGE<br>DAS <span>HERZ</span>', "Ein riesiger Boss wartet auf Ebene 100", "BOSSKAMPF!"),
            ('<span>4+ WELTEN</span><br>ZU EROBERN', "Jede mit eigenem Boss, Musik und Beute", "SCHALTE ALLE FREI"),
            ('<span>LEGENDÄRE</span><br>BEUTE', "42+ Items, 5 Seltenheiten, 3 Truhenarten", "LEGENDÄR!"),
            ('<span>25 PERKS</span><br>ZU MEISTERN', "Prestige, Aufstieg, immer stärker", "PRESTIGE & AUFSTIEG"),
            ('DEINE CREW<br><span>GRÄBT FÜR DICH</span>', "Bergleute verdienen, während du weg bist", "BIS ZU 4 STD."),
        ],
        search='TIPPEN.<br>SCHLAGEN.<br><span>REICH WERDEN!</span>',
        header="Zerschlagen. Plündern. Erobern."),
    "ja": dict(
        shots=[
            ('岩を殴って<br><span>大金持ち！</span>', "タップで砕いて、仲間を雇い、もっと深く", "放置 + タップ"),
            ('<span>ハート</span>を<br>倒せ！', "エリア100で巨大ボスが待つ", "ボス戦！"),
            ('<span>4つ以上の世界</span><br>を制覇せよ', "それぞれにボス、音楽、お宝", "全部解放しよう"),
            ('<span>伝説の</span><br>お宝', "42種以上のアイテム、5つのレアリティ、3種の宝箱", "レジェンダリー！"),
            ('<span>25のパーク</span><br>を極めろ', "転生とアセンションでもっと強く", "転生 & アセンション"),
            ('仲間が<br><span>代わりに掘る</span>', "留守の間も鉱夫が稼ぐ", "最大4時間"),
        ],
        search='タップ！<br>粉砕！<br><span>大金持ち！</span>',
        header="砕け。奪え。制覇せよ。"),
    "ko": dict(
        shots=[
            ('바위를 쳐서<br><span>부자 되기!</span>', "탭해서 부수고, 광부를 고용하고, 더 깊이", "방치 + 탭"),
            ('<span>하트</span>를<br>쓰러뜨려라', "100구역에서 거대 보스가 기다립니다", "보스전!"),
            ('<span>4개 이상의 세계</span><br>정복하기', "세계마다 보스, 음악, 전리품이 가득", "모두 해금하세요"),
            ('<span>전설</span><br>전리품', "42개+ 아이템, 5개 등급, 3종류 상자", "전설!"),
            ('<span>25개 퍽</span><br>마스터하기', "환생하고 승천해서 더 강하게", "환생 & 승천"),
            ('광부들이<br><span>대신 캐요</span>', "자리를 비워도 광부들이 벌어요", "최대 4시간"),
        ],
        search='탭!<br>부숴!<br><span>부자 되기!</span>',
        header="부숴라. 챙겨라. 정복하라."),
    "pt-BR": dict(
        shots=[
            ('SOQUE PEDRAS.<br><span>FIQUE RICO!</span>', "Toque para quebrar, contrate e cave fundo", "IDLE + TAPPER"),
            ('DERROTE<br>O <span>CORAÇÃO</span>', "Um chefão gigante espera na área 100", "LUTA DE CHEFÃO!"),
            ('<span>4+ MUNDOS</span><br>PARA CONQUISTAR', "Cada um com chefão, música e tesouros", "DESBLOQUEIE TODOS"),
            ('ESPÓLIO<br><span>LENDÁRIO</span>', "42+ itens, 5 raridades, 3 tipos de baú", "LENDÁRIO!"),
            ('<span>25 VANTAGENS</span><br>PARA DOMINAR', "Prestígio, ascensão e mais força", "PRESTÍGIO E ASCENSÃO"),
            ('SUA EQUIPE<br><span>CAVA POR VOCÊ</span>', "Mineradores ganham enquanto você está fora", "ATÉ 4 H FORA"),
        ],
        search='TOQUE.<br>QUEBRE.<br><span>FIQUE RICO!</span>',
        header="Quebre. Saqueie. Conquiste."),
    "ro": dict(
        shots=[
            ('LOVEȘTE PIETRE.<br><span>FĂ AVERE!</span>', "Sparge, angajează mineri, sapă mai adânc", "IDLE + TAPPER"),
            ('ÎNVINGE<br><span>INIMA</span>', "Un boss uriaș te așteaptă la nivelul 100", "LUPTĂ CU BOSSUL!"),
            ('<span>4+ LUMI</span><br>DE CUCERIT', "Fiecare cu boss, muzică și comori proprii", "DEBLOCHEAZĂ-LE PE TOATE"),
            ('PRADĂ<br><span>LEGENDARĂ</span>', "42+ obiecte, 5 rarități, 3 tipuri de cufere", "LEGENDAR!"),
            ('<span>25 DE PERKS</span><br>DE STĂPÂNIT', "Prestigiu, ascensiune, tot mai puternic", "PRESTIGIU & ASCENSIUNE"),
            ('ECHIPA TA<br><span>SAPĂ PENTRU TINE</span>', "Minerii câștigă cât timp lipsești", "PÂNĂ LA 4 ORE"),
        ],
        search='LOVEȘTE.<br>SPARGE.<br><span>FĂ AVERE!</span>',
        header="Sparge. Adună. Cucerește."),
    "es-MX": dict(
        shots=[
            ('GOLPEA ROCAS.<br><span>¡HAZTE RICO!</span>', "Toca para romper, contrata y cava más hondo", "IDLE + TAPPER"),
            ('DERROTA<br>AL <span>CORAZÓN</span>', "Un jefe gigante te espera en el área 100", "¡PELEA DE JEFE!"),
            ('<span>4+ MUNDOS</span><br>POR CONQUISTAR', "Cada uno con su jefe, música y botín", "DESBLOQUÉALOS TODOS"),
            ('BOTÍN<br><span>LEGENDARIO</span>', "42+ objetos, 5 rarezas, 3 tipos de cofres", "¡LEGENDARIO!"),
            ('<span>25 VENTAJAS</span><br>POR DOMINAR', "Prestigio, asciende y hazte más fuerte", "PRESTIGIO Y ASCENSIÓN"),
            ('TU EQUIPO<br><span>CAVA POR TI</span>', "Tus mineros ganan mientras no estás", "HASTA 4 H FUERA"),
        ],
        search='TOCA.<br>ROMPE.<br><span>¡HAZTE RICO!</span>',
        header="Rompe. Saquea. Conquista."),
}

# Lilita One and Nunito have no CJK glyphs, so those languages fall back to a heavy CJK face.
# Lilita One also lacks Romanian Ș, Ț and Ă; a per-letter fallback looks broken, so Romanian swaps the whole display face.
_CJK = {"zh-Hans": ("Noto Sans SC", "Noto Sans SC"), "ja": ("Dela Gothic One", "Noto Sans JP"), "ko": ("Black Han Sans", "Noto Sans KR")}


def fonts(code):
    """(<link> tag, display font stack, body font stack, display weight) for a locale."""
    fams = ["Lilita+One", "Nunito:wght@800;900"]
    display, body, weight = "'Lilita One'", "'Nunito'", 400
    if code == "ro":
        fams.append("Baloo+2:wght@800")
        display, weight = "'Baloo 2'", 800
    if code in _CJK:
        d, b = _CJK[code]
        fams += [d.replace(" ", "+") + (":wght@900" if d.startswith("Noto") else ""), b.replace(" ", "+") + ":wght@900"]
        display += f", '{d}', '{b}'"
        body += f", '{b}'"
    link = '<link href="https://fonts.googleapis.com/css2?' + "&".join(f"family={f}" for f in dict.fromkeys(fams)) + '&display=block" rel="stylesheet">'
    return link, display + ", sans-serif", body + ", sans-serif", weight


# Shrinks every .fit element until its single-line content fits its box (max-width or container width).
FIT_JS = '''<script>document.fonts.ready.then(() => {
  for (const el of document.querySelectorAll('.fit')) {
    let fs = parseFloat(getComputedStyle(el).fontSize);
    while (el.scrollWidth > el.clientWidth + 1 && fs > 8) { fs *= 0.97; el.style.fontSize = fs + 'px'; }
  }
});</script>'''
