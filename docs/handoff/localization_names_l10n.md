# Handoff — claves i18n de NOMBRES propios (FE4/FE5)

Para la **sesión de traducción / CSV**. Esta sesión (desarrollo del juego)
**no** edita los CSV; aquí van los datos listos para que los integres tú.

## Qué es
Nombres propios (personajes, lugares, ítems, títulos/facciones) extraídos de
las *name charts* oficiales guardadas en `docs/name_charts/` **más** el
resultado de las votaciones de la comunidad (`docs/name_charts/community_votes.md`).

Propongo un CSV nuevo dedicado, p. ej.:
`assets/languages/<...>/Translations FE45 - Names.csv`

Columnas, en orden (idéntico a los CSV existentes): `,en,es,de,ja,fr,it`.

- **`en`** = nombre que usará el proyecto. Es el localizado de la chart,
  **sobrescrito por el ganador de la votación** cuando la comunidad decidió
  otra grafía. En empates/pluralidades débiles se mantuvo el actual
  (**Andrey**, **Boldor**).
- **`ja`** = katakana/original de la chart.
- **`es` / `de` / `fr` / `it`** = **por rellenar**. Muchos nombres propios se
  quedarán igual que `en`, pero eso lo decides en traducción (algunos tienen
  localización propia por idioma que aún no tenemos en chart).

### Convención de claves
- `NAME_*` personajes · `PLACE_*` lugares · `ITEM_*` ítems ·
  `TITLE_*` títulos/facciones. Sin acentos ni símbolos (p. ej.
  `ITEM_GAEBOLG`, `TITLE_SCIONOFLIGHT`).
- Personajes compartidos entre FE4 y FE5 (Finn, Nanna, Ced, Diarmuid…)
  aparecen **una sola vez** (misma entidad → una clave).

> Nota: las claves de **diálogo** con japonés propio y su comentario
> `⟦latino⟧` (ver `docs/dialogue_localization_handoff.md`) son otro sistema;
> esto de aquí son solo **nombres** para etiquetas de UI/menús.


## Personajes FE4 (86)

| clave | en (proyecto) | ja | es | de | fr | it |
|---|---|---|---|---|---|---|
| `NAME_SIGURD` | Sigurd | シグルド | | | | |
| `NAME_NOISH` | Noish ⭐ | ノイッシュ | | | | |
| `NAME_ALEC` | Alec | アレク | | | | |
| `NAME_ARDEN` | Arden | アーダン | | | | |
| `NAME_AZEL` | Azel ⭐ | アゼル | | | | |
| `NAME_LEX` | Lex | レックス | | | | |
| `NAME_QUAN` | Quan | キュアン | | | | |
| `NAME_ETHLYN` | Ethlyn | エスリン | | | | |
| `NAME_FINN` | Finn | フィン | | | | |
| `NAME_MIDIR` | Midir | ミデェール | | | | |
| `NAME_DEW` | Dew | デュー | | | | |
| `NAME_AIDEEN` | Aideen ⭐ | エーディン | | | | |
| `NAME_AYRA` | Ayra | アイラ | | | | |
| `NAME_DEIRDRE` | Deirdre | ディアドラ | | | | |
| `NAME_JAMKE` | Jamke | ジャムカ | | | | |
| `NAME_HOLYN` | Holyn ⭐ | ホリン | | | | |
| `NAME_LACHESIS` | Lachesis | ラケシス | | | | |
| `NAME_BEOWULF` | Beowulf ⭐ | ベオウルフ | | | | |
| `NAME_LEWYN` | Lewyn | レヴィン | | | | |
| `NAME_SYLVIA` | Sylvia ⭐ | シルヴィア | | | | |
| `NAME_ERINYS` | Erinys | フュリー | | | | |
| `NAME_TAILTIU` | Tailtiu | ティルテュ | | | | |
| `NAME_CLAUDE` | Claude ⭐ | クロード | | | | |
| `NAME_BRIGID` | Brigid | ブリギッド | | | | |
| `NAME_SELIPH` | Seliph | セリス | | | | |
| `NAME_LANA` | Lana | ラナ | | | | |
| `NAME_LARCEI` | Larcei | ラクチェ | | | | |
| `NAME_ULSTER` | Ulster | スカサハ | | | | |
| `NAME_OIFAYE` | Oifaye ⭐ | オイフェ | | | | |
| `NAME_DIARMUID` | Diarmuid | デルムッド | | | | |
| `NAME_LESTER` | Lester | レスター | | | | |
| `NAME_JULIA` | Julia | ユリア | | | | |
| `NAME_FEE` | Fee | フィー | | | | |
| `NAME_ARTHUR` | Arthur | アーサー | | | | |
| `NAME_IUCHAR` | Iuchar | ヨハン | | | | |
| `NAME_IUCHARBA` | Iucharba | ヨハルヴァ | | | | |
| `NAME_SHANNAN` | Shannan | シャナン | | | | |
| `NAME_PATTY` | Patty | パティ | | | | |
| `NAME_LEIF` | Leif | リーフ | | | | |
| `NAME_NANNA` | Nanna | ナンナ | | | | |
| `NAME_ARES` | Ares | アレス | | | | |
| `NAME_LENE` | Lene | リーン | | | | |
| `NAME_TINE` | Tine | ティニー | | | | |
| `NAME_FEBAIL` | Febail | ファバル | | | | |
| `NAME_CED` | Ced | セティ | | | | |
| `NAME_HANNIBAL` | Hannibal | ハンニバル | | | | |
| `NAME_COIRPRE` | Coirpre | コープル | | | | |
| `NAME_ALTENA` | Altena | アルテナ | | | | |
| `NAME_MUIRNE` | Muirne | マナ | | | | |
| `NAME_CREIDNE` | Creidne | ラドネイ | | | | |
| `NAME_DALVIN` | Dalvin | ロドルバン | | | | |
| `NAME_TRISTAN` | Tristan | トリスタン | | | | |
| `NAME_DEIMNE` | Deimne | ディムナ | | | | |
| `NAME_HERMINA` | Hermina | フェミナ | | | | |
| `NAME_AMID` | Amid | アミッド | | | | |
| `NAME_DAISY` | Daisy | デイジー | | | | |
| `NAME_JEANNE` | Jeanne | ジャンヌ | | | | |
| `NAME_LAYLEA` | Laylea | レイリア | | | | |
| `NAME_LINDA` | Linda | リンダ | | | | |
| `NAME_ASAELLO` | Asaello | アサエロ | | | | |
| `NAME_HAWK` | Hawk | ホーク | | | | |
| `NAME_CHARLOT` | Charlot | シャルロー | | | | |
| `NAME_ELDIGAN` | Eldigan | エルトシャン | | | | |
| `NAME_MAHNYA` | Mahnya ⭐ | マーニャ | | | | |
| `NAME_BYRON` | Byron | バイロン | | | | |
| `NAME_AIDA` | Aida | アイダ | | | | |
| `NAME_KINBOIS` | Kinbois ⭐ | キンボイス | | | | |
| `NAME_GANDOLF` | Gandolf ⭐ | ガンドルフ | | | | |
| `NAME_SANDIMA` | Sandima | サンディマ | | | | |
| `NAME_CHAGALL` | Chagall | シャガール | | | | |
| `NAME_ANDREY` | Andrey | アンドレイ | | | | |
| `NAME_LANGBALT` | Langbalt ⭐ | ランゴバルト | | | | |
| `NAME_REPTOR` | Reptor | レプトール | | | | |
| `NAME_DANANN` | Danann | ダナン | | | | |
| `NAME_KUTUZOV` | Kutuzov | クトゥーゾフ | | | | |
| `NAME_ISHTORE` | Ishtore | イシュトー | | | | |
| `NAME_BLOOM` | Bloom | ブルーム | | | | |
| `NAME_ISHTAR` | Ishtar | イシュター | | | | |
| `NAME_TRAVANT` | Travant | トラバント | | | | |
| `NAME_ARION` | Arion | アリオーン | | | | |
| `NAME_HILDA` | Hilda | ヒルダ | | | | |
| `NAME_JULIUS` | Julius | ユリウス | | | | |
| `NAME_ARVIS` | Arvis | アルヴィス | | | | |
| `NAME_BRIAN` | Brian | ブリアン | | | | |
| `NAME_SCIPIO` | Scipio | スコピオ | | | | |
| `NAME_MANFROY` | Manfroy | マンフロイ | | | | |

## Personajes FE5 (51)

| clave | en (proyecto) | ja | es | de | fr | it |
|---|---|---|---|---|---|---|
| `NAME_OSIAN` | Osian | オーシン | | | | |
| `NAME_HALVAN` | Halvan | ハルヴァン | | | | |
| `NAME_EYVEL` | Eyvel | エーヴェル | | | | |
| `NAME_DAGDAR` | Dagdar | ダグダ | | | | |
| `NAME_TANYA` | Tanya | タニア | | | | |
| `NAME_MARTY` | Marty | マーティ | | | | |
| `NAME_RONAN` | Ronan | ロナン | | | | |
| `NAME_SAFY` | Safy | サフィ | | | | |
| `NAME_LIFIS` | Lifis | リフィス | | | | |
| `NAME_MACHYUA` | Machyua | マチュア | | | | |
| `NAME_BRIGHTON` | Brighton | ブライトン | | | | |
| `NAME_LARA` | Lara | ラーラ | | | | |
| `NAME_FERGUS` | Fergus | フェルグス | | | | |
| `NAME_KARIN` | Karin | カリン | | | | |
| `NAME_DALSIN` | Dalsin | ダルシン | | | | |
| `NAME_ASBEL` | Asbel | アスベル | | | | |
| `NAME_HICKS` | Hicks | ヒックス | | | | |
| `NAME_SHIVA` | Shiva | シヴァ | | | | |
| `NAME_CARRION` | Carrion | カリオン | | | | |
| `NAME_SELPHINA` | Selphina | セルフィナ | | | | |
| `NAME_CAIN` | Cain | ケイン | | | | |
| `NAME_ALVA` | Alva | アルバ | | | | |
| `NAME_ROBERT` | Robert | ロベルト | | | | |
| `NAME_FRED` | Fred | フレッド | | | | |
| `NAME_OLWEN` | Olwen | オルエン | | | | |
| `NAME_MAREETA` | Mareeta | マリータ | | | | |
| `NAME_SALEM` | Salem | セイラム | | | | |
| `NAME_PERNE` | Perne | パーン | | | | |
| `NAME_TROUDE` | Troude | トルード | | | | |
| `NAME_TINA` | Tina | ティナ | | | | |
| `NAME_GLADE` | Glade | グレイド | | | | |
| `NAME_DEEN` | Deen | ディーン | | | | |
| `NAME_EDA` | Eda | エダ | | | | |
| `NAME_HOMER` | Homer | ホメロス | | | | |
| `NAME_LINOAN` | Linoan | リノアン | | | | |
| `NAME_RALF` | Ralf | ラルフ | | | | |
| `NAME_ILIOS` | Ilios | イリオス | | | | |
| `NAME_SLEUF` | Sleuf | スルーフ | | | | |
| `NAME_MISHA` | Misha | ミーシャ | | | | |
| `NAME_SARA` | Sara | サラ | | | | |
| `NAME_SHANNAM` | Shannam | シャナム | | | | |
| `NAME_MIRANDA` | Miranda | ミランダ | | | | |
| `NAME_XAVIER` | Xavier | ゼーベイア | | | | |
| `NAME_AMALDA` | Amalda | アマルダ | | | | |
| `NAME_CONOMOR` | Conomor | コノモール | | | | |
| `NAME_SAIAS` | Saias | サイアス | | | | |
| `NAME_GALZUS` | Galzus | ガルザス | | | | |
| `NAME_KEMPF` | Kempf | ケンプフ | | | | |
| `NAME_REINHARDT` | Reinhardt | ラインハルト | | | | |
| `NAME_RAYDRIK` | Raydrik | レイドリック | | | | |
| `NAME_VELD` | Veld | ベルド | | | | |

## Lugares FE4 (12)

| clave | en (proyecto) | ja | es | de | fr | it |
|---|---|---|---|---|---|---|
| `PLACE_JUGDRAL` | Jugdral | ユグドラル | | | | |
| `PLACE_GRANNVALE` | Grannvale | グランベル | | | | |
| `PLACE_BELHALLA` | Belhalla | バーハラ | | | | |
| `PLACE_CHALPHY` | Chalphy | シアルフィ | | | | |
| `PLACE_VERDANE` | Verdane | ヴェルダン | | | | |
| `PLACE_AGUSTRIA` | Agustria | アグストリア | | | | |
| `PLACE_NORDION` | Nordion | ノディオン | | | | |
| `PLACE_SILESSE` | Silesse | シレジア | | | | |
| `PLACE_ISAACH` | Isaach | イザーク | | | | |
| `PLACE_TIRNANOG` | Tirnanog | ティルナノグ | | | | |
| `PLACE_LEONSTER` | Leonster | レンスター | | | | |
| `PLACE_THRACIA` | Thracia | トラキア | | | | |

## Ítems FE4 (10)

| clave | en (proyecto) | ja | es | de | fr | it |
|---|---|---|---|---|---|---|
| `ITEM_TYRFING` | Tyrfing | ティルフィング | | | | |
| `ITEM_BALMUNG` | Balmung | バルムンク | | | | |
| `ITEM_MYSTLETAINN` | Mystletainn | ミストルティン | | | | |
| `ITEM_GAEBOLG` | Gáe Bolg | ゲイボルグ | | | | |
| `ITEM_GUNGNIR` | Gungnir | グングニル | | | | |
| `ITEM_HELSWATH` | Helswath | スワンチカ | | | | |
| `ITEM_YEWFELLE` | Yewfelle | イチイバル | | | | |
| `ITEM_VALFLAME` | Valflame | ファラフレイム | | | | |
| `ITEM_MJOLNIR` | Mjölnir | トールハンマー | | | | |
| `ITEM_FORSETI` | Forseti | フォルセティ | | | | |

## Títulos y facciones FE4 (5)

| clave | en (proyecto) | ja | es | de | fr | it |
|---|---|---|---|---|---|---|
| `TITLE_LOPTYRIAN` | Loptyrian | ロプト教団 | | | | |
| `TITLE_DEADLORDS` | Deadlords | 魔将 | | | | |
| `TITLE_SCIONOFLIGHT` | Scion of Light | 光の公子 | | | | |
| `TITLE_LIONHEART` | Lionheart | 獅子王 | | | | |
| `TITLE_BRAND` | Brand | 聖痕 | | | | |

⭐ = grafía elegida por la comunidad (distinta del localizado inglés).

## CSV listo para pegar

```csv
,en,es,de,ja,fr,it
NAME_SIGURD,Sigurd,,,シグルド,,
NAME_NOISH,Noish,,,ノイッシュ,,
NAME_ALEC,Alec,,,アレク,,
NAME_ARDEN,Arden,,,アーダン,,
NAME_AZEL,Azel,,,アゼル,,
NAME_LEX,Lex,,,レックス,,
NAME_QUAN,Quan,,,キュアン,,
NAME_ETHLYN,Ethlyn,,,エスリン,,
NAME_FINN,Finn,,,フィン,,
NAME_MIDIR,Midir,,,ミデェール,,
NAME_DEW,Dew,,,デュー,,
NAME_AIDEEN,Aideen,,,エーディン,,
NAME_AYRA,Ayra,,,アイラ,,
NAME_DEIRDRE,Deirdre,,,ディアドラ,,
NAME_JAMKE,Jamke,,,ジャムカ,,
NAME_HOLYN,Holyn,,,ホリン,,
NAME_LACHESIS,Lachesis,,,ラケシス,,
NAME_BEOWULF,Beowulf,,,ベオウルフ,,
NAME_LEWYN,Lewyn,,,レヴィン,,
NAME_SYLVIA,Sylvia,,,シルヴィア,,
NAME_ERINYS,Erinys,,,フュリー,,
NAME_TAILTIU,Tailtiu,,,ティルテュ,,
NAME_CLAUDE,Claude,,,クロード,,
NAME_BRIGID,Brigid,,,ブリギッド,,
NAME_SELIPH,Seliph,,,セリス,,
NAME_LANA,Lana,,,ラナ,,
NAME_LARCEI,Larcei,,,ラクチェ,,
NAME_ULSTER,Ulster,,,スカサハ,,
NAME_OIFAYE,Oifaye,,,オイフェ,,
NAME_DIARMUID,Diarmuid,,,デルムッド,,
NAME_LESTER,Lester,,,レスター,,
NAME_JULIA,Julia,,,ユリア,,
NAME_FEE,Fee,,,フィー,,
NAME_ARTHUR,Arthur,,,アーサー,,
NAME_IUCHAR,Iuchar,,,ヨハン,,
NAME_IUCHARBA,Iucharba,,,ヨハルヴァ,,
NAME_SHANNAN,Shannan,,,シャナン,,
NAME_PATTY,Patty,,,パティ,,
NAME_LEIF,Leif,,,リーフ,,
NAME_NANNA,Nanna,,,ナンナ,,
NAME_ARES,Ares,,,アレス,,
NAME_LENE,Lene,,,リーン,,
NAME_TINE,Tine,,,ティニー,,
NAME_FEBAIL,Febail,,,ファバル,,
NAME_CED,Ced,,,セティ,,
NAME_HANNIBAL,Hannibal,,,ハンニバル,,
NAME_COIRPRE,Coirpre,,,コープル,,
NAME_ALTENA,Altena,,,アルテナ,,
NAME_MUIRNE,Muirne,,,マナ,,
NAME_CREIDNE,Creidne,,,ラドネイ,,
NAME_DALVIN,Dalvin,,,ロドルバン,,
NAME_TRISTAN,Tristan,,,トリスタン,,
NAME_DEIMNE,Deimne,,,ディムナ,,
NAME_HERMINA,Hermina,,,フェミナ,,
NAME_AMID,Amid,,,アミッド,,
NAME_DAISY,Daisy,,,デイジー,,
NAME_JEANNE,Jeanne,,,ジャンヌ,,
NAME_LAYLEA,Laylea,,,レイリア,,
NAME_LINDA,Linda,,,リンダ,,
NAME_ASAELLO,Asaello,,,アサエロ,,
NAME_HAWK,Hawk,,,ホーク,,
NAME_CHARLOT,Charlot,,,シャルロー,,
NAME_ELDIGAN,Eldigan,,,エルトシャン,,
NAME_MAHNYA,Mahnya,,,マーニャ,,
NAME_BYRON,Byron,,,バイロン,,
NAME_AIDA,Aida,,,アイダ,,
NAME_KINBOIS,Kinbois,,,キンボイス,,
NAME_GANDOLF,Gandolf,,,ガンドルフ,,
NAME_SANDIMA,Sandima,,,サンディマ,,
NAME_CHAGALL,Chagall,,,シャガール,,
NAME_ANDREY,Andrey,,,アンドレイ,,
NAME_LANGBALT,Langbalt,,,ランゴバルト,,
NAME_REPTOR,Reptor,,,レプトール,,
NAME_DANANN,Danann,,,ダナン,,
NAME_KUTUZOV,Kutuzov,,,クトゥーゾフ,,
NAME_ISHTORE,Ishtore,,,イシュトー,,
NAME_BLOOM,Bloom,,,ブルーム,,
NAME_ISHTAR,Ishtar,,,イシュター,,
NAME_TRAVANT,Travant,,,トラバント,,
NAME_ARION,Arion,,,アリオーン,,
NAME_HILDA,Hilda,,,ヒルダ,,
NAME_JULIUS,Julius,,,ユリウス,,
NAME_ARVIS,Arvis,,,アルヴィス,,
NAME_BRIAN,Brian,,,ブリアン,,
NAME_SCIPIO,Scipio,,,スコピオ,,
NAME_MANFROY,Manfroy,,,マンフロイ,,
PLACE_JUGDRAL,Jugdral,,,ユグドラル,,
PLACE_GRANNVALE,Grannvale,,,グランベル,,
PLACE_BELHALLA,Belhalla,,,バーハラ,,
PLACE_CHALPHY,Chalphy,,,シアルフィ,,
PLACE_VERDANE,Verdane,,,ヴェルダン,,
PLACE_AGUSTRIA,Agustria,,,アグストリア,,
PLACE_NORDION,Nordion,,,ノディオン,,
PLACE_SILESSE,Silesse,,,シレジア,,
PLACE_ISAACH,Isaach,,,イザーク,,
PLACE_TIRNANOG,Tirnanog,,,ティルナノグ,,
PLACE_LEONSTER,Leonster,,,レンスター,,
PLACE_THRACIA,Thracia,,,トラキア,,
TITLE_LOPTYRIAN,Loptyrian,,,ロプト教団,,
TITLE_DEADLORDS,Deadlords,,,魔将,,
TITLE_SCIONOFLIGHT,Scion of Light,,,光の公子,,
TITLE_LIONHEART,Lionheart,,,獅子王,,
TITLE_BRAND,Brand,,,聖痕,,
ITEM_TYRFING,Tyrfing,,,ティルフィング,,
ITEM_BALMUNG,Balmung,,,バルムンク,,
ITEM_MYSTLETAINN,Mystletainn,,,ミストルティン,,
ITEM_GAEBOLG,Gáe Bolg,,,ゲイボルグ,,
ITEM_GUNGNIR,Gungnir,,,グングニル,,
ITEM_HELSWATH,Helswath,,,スワンチカ,,
ITEM_YEWFELLE,Yewfelle,,,イチイバル,,
ITEM_VALFLAME,Valflame,,,ファラフレイム,,
ITEM_MJOLNIR,Mjölnir,,,トールハンマー,,
ITEM_FORSETI,Forseti,,,フォルセティ,,
NAME_OSIAN,Osian,,,オーシン,,
NAME_HALVAN,Halvan,,,ハルヴァン,,
NAME_EYVEL,Eyvel,,,エーヴェル,,
NAME_DAGDAR,Dagdar,,,ダグダ,,
NAME_TANYA,Tanya,,,タニア,,
NAME_MARTY,Marty,,,マーティ,,
NAME_RONAN,Ronan,,,ロナン,,
NAME_SAFY,Safy,,,サフィ,,
NAME_LIFIS,Lifis,,,リフィス,,
NAME_MACHYUA,Machyua,,,マチュア,,
NAME_BRIGHTON,Brighton,,,ブライトン,,
NAME_LARA,Lara,,,ラーラ,,
NAME_FERGUS,Fergus,,,フェルグス,,
NAME_KARIN,Karin,,,カリン,,
NAME_DALSIN,Dalsin,,,ダルシン,,
NAME_ASBEL,Asbel,,,アスベル,,
NAME_HICKS,Hicks,,,ヒックス,,
NAME_SHIVA,Shiva,,,シヴァ,,
NAME_CARRION,Carrion,,,カリオン,,
NAME_SELPHINA,Selphina,,,セルフィナ,,
NAME_CAIN,Cain,,,ケイン,,
NAME_ALVA,Alva,,,アルバ,,
NAME_ROBERT,Robert,,,ロベルト,,
NAME_FRED,Fred,,,フレッド,,
NAME_OLWEN,Olwen,,,オルエン,,
NAME_MAREETA,Mareeta,,,マリータ,,
NAME_SALEM,Salem,,,セイラム,,
NAME_PERNE,Perne,,,パーン,,
NAME_TROUDE,Troude,,,トルード,,
NAME_TINA,Tina,,,ティナ,,
NAME_GLADE,Glade,,,グレイド,,
NAME_DEEN,Deen,,,ディーン,,
NAME_EDA,Eda,,,エダ,,
NAME_HOMER,Homer,,,ホメロス,,
NAME_LINOAN,Linoan,,,リノアン,,
NAME_RALF,Ralf,,,ラルフ,,
NAME_ILIOS,Ilios,,,イリオス,,
NAME_SLEUF,Sleuf,,,スルーフ,,
NAME_MISHA,Misha,,,ミーシャ,,
NAME_SARA,Sara,,,サラ,,
NAME_SHANNAM,Shannam,,,シャナム,,
NAME_MIRANDA,Miranda,,,ミランダ,,
NAME_XAVIER,Xavier,,,ゼーベイア,,
NAME_AMALDA,Amalda,,,アマルダ,,
NAME_CONOMOR,Conomor,,,コノモール,,
NAME_SAIAS,Saias,,,サイアス,,
NAME_GALZUS,Galzus,,,ガルザス,,
NAME_KEMPF,Kempf,,,ケンプフ,,
NAME_REINHARDT,Reinhardt,,,ラインハルト,,
NAME_RAYDRIK,Raydrik,,,レイドリック,,
NAME_VELD,Veld,,,ベルド,,
```

## ⚠️ Renombres de nid (sesión de juego) — reconciliar claves de Characters.csv

Esta sesión alineó varios **nid** internos con el nombre mostrado (y añadió
1 unidad nueva). La `Translations FE45 - Characters.csv` que subiste usa como
**clave** (1ª columna) el nid **viejo** en varios casos; si la localización de
nombres se va a indexar por el nid de la unidad, esas claves hay que
actualizarlas. El **texto mostrado** (columnas en/es/… ) ya es correcto.

| Clave actual en CSV | nid nuevo (unidad) | Mostrado | Juego |
|---|---|---|---|
| `RODDLEVAN` | `Dalvin` | Dalvin | FE4 |
| `PAHN` | `Perne` | Perne | FE5 |
| `CORUTA` | `Coulter` | Coulter | FE4 |
| `DIMNA` | `Deimne` | Deimne | FE4 |
| `MANA` | `Muirne` | Muirne | FE4 |
| `RADNEY` | `Creidne` | Creidne | FE4 |
| `SHARLOW` | `Charlot` | Charlot | FE4 |
| `FEMINA` | `Hermina` | Hermina | FE4 |
| `DIARMUID` | `Diarmuid` | Diarmuid | FE4/FE5 | *(ya coincide; antes el nid era `Delmud`, ahora unificado a `Diarmuid`; `Delmud` queda solo como NoJ en las charts)* |

Además, unidad **nueva** creada esta sesión (ya presente en tu CSV como `BROOK`):
`Brook` (ブルック) — jefe FE5 General. Sin cambios necesarios en la clave.

> Sugerencia (opcional): si el sistema de nombres se indexa por nid, cambiar
> las 8 claves de arriba al nid nuevo. Si en cambio usa una clave estable tipo
> `NAME_*` (como propone este handoff), no hace falta tocar nada más que
> mantener el mapeo clave→unidad en el código de carga.

## Pendiente (no en las charts todavía)
Enemigos menores / jefes secundarios sin entrada en las charts actuales
(Elliot, Gerrard, Macbeth, los jefes-bestia de FE4, los jefes con número
alemán de FE5 Eins…Zwölf, etc.). Cuando el autor confirme su japonés se
añadirán con el mismo esquema `NAME_*`.

