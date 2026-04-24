"""
seed_phonemes.py
================
Populates the database with:
  - 42 Lesson rows  (8 units × up to 6 lessons each)
  - 90 Phoneme rows (with global order for the sequencing rule)
  - Initial word-type Exercise rows from the JSON exercises list

Run from backend/ directory:
    source venv/bin/activate
    python seed_phonemes.py

Safe to re-run: uses get-or-create for every row so nothing is duplicated.
"""

import asyncio
import logging
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

# Must import all models before using them so SQLAlchemy resolves relationships
import app.models  # noqa: F401
from app.db.session import AsyncSessionLocal
from app.models.enums import ExerciseType, Level, PhonemeType
from app.models.exercise import Exercise
from app.models.lesson import Lesson
from app.models.phoneme import Phoneme

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Map JSON type strings → PhonemeType enum
# ---------------------------------------------------------------------------
PHONEME_TYPE_MAP: dict[str, PhonemeType] = {
    "alphabet": PhonemeType.ALPHABET,
    "long vowel": PhonemeType.LONG_VOWEL,
    "short vowel": PhonemeType.SHORT_VOWEL,
    "consonant blend": PhonemeType.CONSONANT_BLEND,
    "letter combination": PhonemeType.LETTER_COMBINATION,
    "r-controlled vowel": PhonemeType.R_CONTROLLED_VOWEL,
    "diphthong": PhonemeType.DIPHTHONG,
    "schwa": PhonemeType.SCHWA,
    "silent letters": PhonemeType.SILENT_LETTER,
    "suffix": PhonemeType.SUFFIX,
}

# ---------------------------------------------------------------------------
# Map UNIT name → Level enum
# ---------------------------------------------------------------------------
UNIT_LEVEL_MAP: dict[str, Level] = {
    "UNIT1": Level.LEVEL1,
    "UNIT2": Level.LEVEL1,
    "UNIT3": Level.LEVEL2,
    "UNIT4": Level.LEVEL2,
    "UNIT5": Level.LEVEL3,
    "UNIT6": Level.LEVEL3,
    "UNIT7": Level.LEVEL4,
    "UNIT8": Level.LEVEL5,
}

# ---------------------------------------------------------------------------
# Map UNIT name → lesson order base (so lessons across units don't collide)
# UNIT1 lessons get order 1-6, UNIT2 get 7-12, etc.
# ---------------------------------------------------------------------------
UNIT_ORDER_BASE: dict[str, int] = {
    "UNIT1": 0,
    "UNIT2": 6,
    "UNIT3": 12,
    "UNIT4": 18,
    "UNIT5": 24,
    "UNIT6": 30,
    "UNIT7": 36,
    "UNIT8": 42,
}

# ---------------------------------------------------------------------------
# All 90 phonemes — derived directly from phoneme.json
# Fields: id, symbol, description, audio_url, unit, lesson_number,
#         phoneme_type, exercises (word list for initial exercise seeding)
# ---------------------------------------------------------------------------
PHONEMES = [
    # ── UNIT 1 ──────────────────────────────────────────────────────────────
    dict(
        id=1,
        symbol="a",
        unit="UNIT1",
        lesson=1,
        type="alphabet",
        description="Short vowel sound /æ/ as in 'apple', written with the letter A.",
        audio_url="http://localhost/static/audio/sound_a.mp3",
        exercises=["apple", "ax", "ant", "alligator"],
    ),
    dict(
        id=2,
        symbol="b",
        unit="UNIT1",
        lesson=2,
        type="alphabet",
        description="Voiced bilabial plosive /b/ as in 'bear', written with the letter B.",
        audio_url="http://localhost/static/audio/sound_b.mp3",
        exercises=["bear", "bird", "bed", "banana"],
    ),
    dict(
        id=3,
        symbol="k",
        unit="UNIT1",
        lesson=3,
        type="alphabet",
        description="Voiceless velar plosive /k/ as in 'cat', written with the letter C.",
        audio_url="http://localhost/static/audio/sound_c.mp3",
        exercises=["cat", "cup", "car", "computer"],
    ),
    dict(
        id=27,
        symbol="eɪ (a_e)",
        unit="UNIT1",
        lesson=1,
        type="long vowel",
        description="Long A sound /eɪ/ spelled a_e as in 'tape' and 'cake'.",
        audio_url="http://localhost/static/audio/sound_a_e.mp3",
        exercises=[
            "tape",
            "cape",
            "cane",
            "mane",
            "game",
            "cake",
            "name",
            "lake",
            "gate",
            "wave",
            "skate",
            "cave",
        ],
    ),
    dict(
        id=72,
        symbol="ar",
        unit="UNIT1",
        lesson=1,
        type="r-controlled vowel",
        description="R-controlled vowel /ɑːr/ as in 'car' and 'farm'.",
        audio_url="http://localhost/static/audio/sound_ar.mp3",
        exercises=["car", "farm", "park", "star"],
    ),
    dict(
        id=73,cd ..
alembic upgrade head
        symbol="ɜːr (ir/ur)",
        unit="UNIT1",
        lesson=2,
        type="r-controlled vowel",
        description="R-controlled vowel /ɜːr/ spelled ir/ur as in 'bird' and 'nurse'.",
        audio_url="http://localhost/static/audio/sound_ir_ur.mp3",
        exercises=["bird", "girl", "nurse", "purple"],
    ),
    dict(
        id=74,
        symbol="ər (er/or)",
        unit="UNIT1",
        lesson=3,
        type="r-controlled vowel",
        description="R-controlled vowel spelled er/or as in 'teacher' and 'doctor'.",
        audio_url="http://localhost/static/audio/sound_er_or.mp3",
        exercises=["teacher", "sister", "doctor", "tractor"],
    ),
    # ── UNIT 2 ──────────────────────────────────────────────────────────────
    dict(
        id=4,
        symbol="d",
        unit="UNIT2",
        lesson=1,
        type="alphabet",
        description="Voiced alveolar plosive /d/ as in 'dog', written with the letter D.",
        audio_url="http://localhost/static/audio/sound_d.mp3",
        exercises=["dog", "desk", "doll", "duck"],
    ),
    dict(
        id=5,
        symbol="e",
        unit="UNIT2",
        lesson=2,
        type="alphabet",
        description="Short vowel sound /e/ as in 'egg', written with the letter E.",
        audio_url="http://localhost/static/audio/sound_e.mp3",
        exercises=["egg", "elbow", "envelope", "elephant"],
    ),
    dict(
        id=6,
        symbol="f",
        unit="UNIT2",
        lesson=3,
        type="alphabet",
        description="Voiceless labiodental fricative /f/ as in 'fish', written with the letter F.",
        audio_url="http://localhost/static/audio/sound_f.mp3",
        exercises=["fish", "fan", "farm", "fork"],
    ),
    dict(
        id=28,
        symbol="aɪ (i_e)",
        unit="UNIT2",
        lesson=1,
        type="long vowel",
        description="Long I sound /aɪ/ spelled i_e as in 'kite' and 'time'.",
        audio_url="http://localhost/static/audio/sound_i_e.mp3",
        exercises=[
            "kite",
            "pine",
            "ripe",
            "fine",
            "lime",
            "bike",
            "time",
            "hike",
            "five",
            "nine",
            "dive",
            "line",
        ],
    ),
    dict(
        id=40,
        symbol="fr",
        unit="UNIT2",
        lesson=1,
        type="consonant blend",
        description="Consonant blend /fr/ as in 'frog' and 'Friday'.",
        audio_url="http://localhost/static/audio/sound_fr.mp3",
        exercises=["frog", "Friday"],
    ),
    dict(
        id=41,
        symbol="gr",
        unit="UNIT2",
        lesson=2,
        type="consonant blend",
        description="Consonant blend /gr/ as in 'green' and 'grass'.",
        audio_url="http://localhost/static/audio/sound_gr.mp3",
        exercises=["green", "grass"],
    ),
    dict(
        id=42,
        symbol="pl",
        unit="UNIT2",
        lesson=3,
        type="consonant blend",
        description="Consonant blend /pl/ as in 'plate' and 'play'.",
        audio_url="http://localhost/static/audio/sound_pl.mp3",
        exercises=["plate", "play"],
    ),
    dict(
        id=43,
        symbol="sl",
        unit="UNIT2",
        lesson=4,
        type="consonant blend",
        description="Consonant blend /sl/ as in 'slide' and 'sleep'.",
        audio_url="http://localhost/static/audio/sound_sl.mp3",
        exercises=["slide", "sleep"],
    ),
    dict(
        id=44,
        symbol="dr",
        unit="UNIT2",
        lesson=5,
        type="consonant blend",
        description="Consonant blend /dr/ as in 'drum' and 'dress'.",
        audio_url="http://localhost/static/audio/sound_dr.mp3",
        exercises=["drum", "dress"],
    ),
    dict(
        id=45,
        symbol="tr",
        unit="UNIT2",
        lesson=6,
        type="consonant blend",
        description="Consonant blend /tr/ as in 'truck' and 'tree'.",
        audio_url="http://localhost/static/audio/sound_tr.mp3",
        exercises=["truck", "tree"],
    ),
    dict(
        id=75,
        symbol="aʊ (ou/ow)",
        unit="UNIT2",
        lesson=1,
        type="diphthong",
        description="Diphthong /aʊ/ spelled ou/ow as in 'mouse' and 'cow'.",
        audio_url="http://localhost/static/audio/sound_ou_ow.mp3",
        exercises=["mouse", "house", "cow", "brown"],
    ),
    dict(
        id=76,
        symbol="ɔɪ (oi/oy)",
        unit="UNIT2",
        lesson=2,
        type="diphthong",
        description="Diphthong /ɔɪ/ spelled oi/oy as in 'coin' and 'boy'.",
        audio_url="http://localhost/static/audio/sound_oi_oy.mp3",
        exercises=["coin", "soil", "toy", "boy"],
    ),
    dict(
        id=77,
        symbol="ʊ/ʌ (oo/u)",
        unit="UNIT2",
        lesson=3,
        type="letter combination",
        description="Short vowel /ʊ/ or /ʌ/ in words like 'book', 'foot', and 'bush'.",
        audio_url="http://localhost/static/audio/sound_oo_u.mp3",
        exercises=["book", "foot", "bush", "pull"],
    ),
    # ── UNIT 3 ──────────────────────────────────────────────────────────────
    dict(
        id=7,
        symbol="g",
        unit="UNIT3",
        lesson=1,
        type="alphabet",
        description="Hard /g/ sound, voiced velar plosive as in 'gorilla', written with G.",
        audio_url="http://localhost/static/audio/sound_g.mp3",
        exercises=["gorilla", "goat", "gift", "girl"],
    ),
    dict(
        id=8,
        symbol="h",
        unit="UNIT3",
        lesson=2,
        type="alphabet",
        description="Glottal fricative /h/ as in 'horse', written with the letter H.",
        audio_url="http://localhost/static/audio/sound_h.mp3",
        exercises=["horse", "hat", "house", "hot dog"],
    ),
    dict(
        id=9,
        symbol="ɪ",
        unit="UNIT3",
        lesson=3,
        type="alphabet",
        description="Short vowel sound /ɪ/ as in 'insect', written with I.",
        audio_url="http://localhost/static/audio/sound_i.mp3",
        exercises=["insect", "ink", "igloo", "iguana"],
    ),
    dict(
        id=29,
        symbol="oʊ (o_e)",
        unit="UNIT3",
        lesson=1,
        type="long vowel",
        description="Long O sound /oʊ/ spelled o_e as in 'home' and 'rope'.",
        audio_url="http://localhost/static/audio/sound_o_e.mp3",
        exercises=["home", "bone", "cone", "rope"],
    ),
    dict(
        id=30,
        symbol="uː (u_e)",
        unit="UNIT3",
        lesson=2,
        type="long vowel",
        description="Long U sound /juː/ or /uː/ spelled u_e as in 'cube' and 'mule'.",
        audio_url="http://localhost/static/audio/sound_u_e.mp3",
        exercises=["cube", "mute", "cute", "mule", "tube", "June", "tune", "rule"],
    ),
    dict(
        id=46,
        symbol="sm",
        unit="UNIT3",
        lesson=1,
        type="consonant blend",
        description="Consonant blend /sm/ as in 'smile' and 'smoke'.",
        audio_url="http://localhost/static/audio/sound_sm.mp3",
        exercises=["smile", "smoke"],
    ),
    dict(
        id=47,
        symbol="sn",
        unit="UNIT3",
        lesson=2,
        type="consonant blend",
        description="Consonant blend /sn/ as in 'snake' and 'snow'.",
        audio_url="http://localhost/static/audio/sound_sn.mp3",
        exercises=["snake", "snow"],
    ),
    dict(
        id=48,
        symbol="sp",
        unit="UNIT3",
        lesson=3,
        type="consonant blend",
        description="Consonant blend /sp/ as in 'spoon' and 'spot'.",
        audio_url="http://localhost/static/audio/sound_sp.mp3",
        exercises=["spoon", "spot"],
    ),
    dict(
        id=49,
        symbol="sw",
        unit="UNIT3",
        lesson=4,
        type="consonant blend",
        description="Consonant blend /sw/ as in 'swing' and 'swim'.",
        audio_url="http://localhost/static/audio/sound_sw.mp3",
        exercises=["swing", "swim"],
    ),
    dict(
        id=50,
        symbol="st",
        unit="UNIT3",
        lesson=5,
        type="consonant blend",
        description="Consonant blend /st/ as in 'stop' and 'stamp'.",
        audio_url="http://localhost/static/audio/sound_st.mp3",
        exercises=["stop", "stamp", "test", "fast"],
    ),
    dict(
        id=78,
        symbol="ɔː (au/aw)",
        unit="UNIT3",
        lesson=1,
        type="letter combination",
        description="Vowel /ɔː/ spelled au/aw as in 'sauce' and 'prawn'.",
        audio_url="http://localhost/static/audio/sound_au_aw.mp3",
        exercises=["sauce", "August", "prawn", "draw"],
    ),
    dict(
        id=79,
        symbol="ɔː (or/oar)",
        unit="UNIT3",
        lesson=3,
        type="r-controlled vowel",
        description="R-colored /ɔːr/ spelled or/oar as in 'horse' and 'board'.",
        audio_url="http://localhost/static/audio/sound_or_oar.mp3",
        exercises=["horse", "fork", "roar", "board"],
    ),
    # ── UNIT 4 ──────────────────────────────────────────────────────────────
    dict(
        id=10,
        symbol="dʒ",
        unit="UNIT4",
        lesson=1,
        type="alphabet",
        description="Affricate /dʒ/ as in 'jet', written with J.",
        audio_url="http://localhost/static/audio/sound_j.mp3",
        exercises=["jet", "jam", "juice", "jacket"],
    ),
    dict(
        id=11,
        symbol="kʰ",
        unit="UNIT4",
        lesson=2,
        type="alphabet",
        description="Hard /k/ sound as in 'kangaroo', written with K.",
        audio_url="http://localhost/static/audio/sound_k.mp3",
        exercises=["kangaroo", "key", "king", "kite"],
    ),
    dict(
        id=12,
        symbol="l",
        unit="UNIT4",
        lesson=3,
        type="alphabet",
        description="Lateral approximant /l/ as in 'lion', written with L.",
        audio_url="http://localhost/static/audio/sound_l.mp3",
        exercises=["lion", "lamp", "leaf", "lemon"],
    ),
    dict(
        id=31,
        symbol="eɪ (ai)",
        unit="UNIT4",
        lesson=1,
        type="long vowel",
        description="Long A sound /eɪ/ spelled ai as in 'rain' and 'tail'.",
        audio_url="http://localhost/static/audio/sound_ai.mp3",
        exercises=["rain", "nail", "tail", "wait"],
    ),
    dict(
        id=32,
        symbol="eɪ (ay)",
        unit="UNIT4",
        lesson=2,
        type="long vowel",
        description="Long A sound /eɪ/ spelled ay as in 'day' and 'bay'.",
        audio_url="http://localhost/static/audio/sound_ay.mp3",
        exercises=["bay", "day", "say", "pay", "sail", "mail", "hay", "May"],
    ),
    dict(
        id=34,
        symbol="bl",
        unit="UNIT4",
        lesson=1,
        type="consonant blend",
        description="Consonant blend /bl/ as in 'black' and 'blanket'.",
        audio_url="http://localhost/static/audio/sound_bl.mp3",
        exercises=["black", "blanket", "blue", "block", "blow"],
    ),
    dict(
        id=35,
        symbol="cl",
        unit="UNIT4",
        lesson=2,
        type="consonant blend",
        description="Consonant blend /kl/ as in 'clock' and 'club'.",
        audio_url="http://localhost/static/audio/sound_cl.mp3",
        exercises=["clock", "club", "clue", "clean"],
    ),
    dict(
        id=36,
        symbol="br",
        unit="UNIT4",
        lesson=3,
        type="consonant blend",
        description="Consonant blend /br/ as in 'broom'.",
        audio_url="http://localhost/static/audio/sound_br.mp3",
        exercises=["broom", "bride"],
    ),
    dict(
        id=37,
        symbol="cr",
        unit="UNIT4",
        lesson=4,
        type="consonant blend",
        description="Consonant blend /kr/ as in 'crab' and 'crocodile'.",
        audio_url="http://localhost/static/audio/sound_cr.mp3",
        exercises=["crab", "crocodile"],
    ),
    dict(
        id=38,
        symbol="fl",
        unit="UNIT4",
        lesson=5,
        type="consonant blend",
        description="Consonant blend /fl/ as in 'fly' and 'flag'.",
        audio_url="http://localhost/static/audio/sound_fl.mp3",
        exercises=["fly", "flag"],
    ),
    dict(
        id=39,
        symbol="gl",
        unit="UNIT4",
        lesson=6,
        type="consonant blend",
        description="Consonant blend /gl/ as in 'globe' and 'glass'.",
        audio_url="http://localhost/static/audio/sound_gl.mp3",
        exercises=["globe", "glass"],
    ),
    dict(
        id=51,
        symbol="ʃ (sh)",
        unit="UNIT4",
        lesson=1,
        type="letter combination",
        description="Consonant digraph /ʃ/ as in 'shell' and 'fish', spelled sh.",
        audio_url="http://localhost/static/audio/sound_sh.mp3",
        exercises=["shell", "fish", "ship", "brush"],
    ),
    dict(
        id=52,
        symbol="tʃ (ch)",
        unit="UNIT4",
        lesson=2,
        type="letter combination",
        description="Affricate /tʃ/ as in 'chick' and 'catch', spelled ch or tch.",
        audio_url="http://localhost/static/audio/sound_ch.mp3",
        exercises=["chick", "lunch", "watch", "catch"],
    ),
    dict(
        id=53,
        symbol="f (ph)",
        unit="UNIT4",
        lesson=3,
        type="letter combination",
        description="Ph digraph pronounced /f/ as in 'phone' and 'dolphin'.",
        audio_url="http://localhost/static/audio/sound_ph.mp3",
        exercises=["phone", "dolphin"],
    ),
    dict(
        id=54,
        symbol="w (wh)",
        unit="UNIT4",
        lesson=4,
        type="letter combination",
        description="Digraph wh usually pronounced /w/ as in 'whale' and 'white'.",
        audio_url="http://localhost/static/audio/sound_wh.mp3",
        exercises=["whale", "white"],
    ),
    # ── UNIT 5 ──────────────────────────────────────────────────────────────
    dict(
        id=13,
        symbol="m",
        unit="UNIT5",
        lesson=1,
        type="alphabet",
        description="Bilabial nasal /m/ as in 'monkey', written with M.",
        audio_url="http://localhost/static/audio/sound_m.mp3",
        exercises=["monkey", "milk", "money", "mouse"],
    ),
    dict(
        id=14,
        symbol="n",
        unit="UNIT5",
        lesson=2,
        type="alphabet",
        description="Alveolar nasal /n/ as in 'nut', written with N.",
        audio_url="http://localhost/static/audio/sound_n.mp3",
        exercises=["nut", "net", "nest", "nose"],
    ),
    dict(
        id=15,
        symbol="ɒ/ɔ",
        unit="UNIT5",
        lesson=3,
        type="alphabet",
        description="Short o vowel as in 'octopus', written with O.",
        audio_url="http://localhost/static/audio/sound_o.mp3",
        exercises=["octopus", "ox", "olive", "ostrich"],
    ),
    dict(
        id=33,
        symbol="iː (ee/ea)",
        unit="UNIT5",
        lesson=1,
        type="long vowel",
        description="Long E sound /iː/ spelled ee/ea as in 'feet' and 'leaf'.",
        audio_url="http://localhost/static/audio/sound_long_e.mp3",
        exercises=["bee", "feet", "seed", "jeep", "leaf", "eat", "sea", "meat"],
    ),
    dict(
        id=55,
        symbol="ð (voiced th)",
        unit="UNIT5",
        lesson=1,
        type="letter combination",
        description="Voiced dental fricative /ð/ as in 'this' and 'mother'.",
        audio_url="http://localhost/static/audio/sound_th_voiced.mp3",
        exercises=["this", "that", "mother", "father"],
    ),
    dict(
        id=56,
        symbol="θ (unvoiced th)",
        unit="UNIT5",
        lesson=2,
        type="letter combination",
        description="Voiceless dental fricative /θ/ as in 'three' and 'think'.",
        audio_url="http://localhost/static/audio/sound_th_unvoiced.mp3",
        exercises=["three", "teeth", "think", "bath"],
    ),
    dict(
        id=57,
        symbol="ck",
        unit="UNIT5",
        lesson=3,
        type="letter combination",
        description="Letter combination ck representing /k/ at the end of a syllable.",
        audio_url="http://localhost/static/audio/sound_ck.mp3",
        exercises=["duck", "rocket"],
    ),
    dict(
        id=58,
        symbol="qu",
        unit="UNIT5",
        lesson=4,
        type="letter combination",
        description="Letter combination qu representing /kw/ as in 'queen'.",
        audio_url="http://localhost/static/audio/sound_qu.mp3",
        exercises=["queen", "quilt"],
    ),
    # ── UNIT 6 ──────────────────────────────────────────────────────────────
    dict(
        id=16,
        symbol="p",
        unit="UNIT6",
        lesson=1,
        type="alphabet",
        description="Voiceless bilabial plosive /p/ as in 'peach', written with P.",
        audio_url="http://localhost/static/audio/sound_p.mp3",
        exercises=["peach", "pen", "panda", "pineapple"],
    ),
    dict(
        id=17,
        symbol="kw",
        unit="UNIT6",
        lesson=2,
        type="alphabet",
        description="Consonant cluster /kw/ as in 'queen', written with Q.",
        audio_url="http://localhost/static/audio/sound_q.mp3",
        exercises=["queen", "quiz", "quilt", "question"],
    ),
    dict(
        id=18,
        symbol="r",
        unit="UNIT6",
        lesson=3,
        type="alphabet",
        description="Approximant /r/ as in 'rabbit', written with R.",
        audio_url="http://localhost/static/audio/sound_r.mp3",
        exercises=["rabbit", "rose", "rice", "robot"],
    ),
    dict(
        id=59,
        symbol="ŋ (ng)",
        unit="UNIT6",
        lesson=1,
        type="letter combination",
        description="Nasal /ŋ/ as in 'king' and 'long', spelled ng.",
        audio_url="http://localhost/static/audio/sound_ng.mp3",
        exercises=["king", "long"],
    ),
    dict(
        id=60,
        symbol="nk",
        unit="UNIT6",
        lesson=2,
        type="letter combination",
        description="Final consonant cluster /ŋk/ as in 'bank' and 'pink'.",
        audio_url="http://localhost/static/audio/sound_nk.mp3",
        exercises=["bank", "pink"],
    ),
    dict(
        id=61,
        symbol="nd",
        unit="UNIT6",
        lesson=3,
        type="letter combination",
        description="Final consonant cluster /nd/ as in 'wind' and 'hand'.",
        audio_url="http://localhost/static/audio/sound_nd.mp3",
        exercises=["wind", "hand"],
    ),
    dict(
        id=62,
        symbol="nt",
        unit="UNIT6",
        lesson=4,
        type="letter combination",
        description="Final consonant cluster /nt/ as in 'tent' and 'paint'.",
        audio_url="http://localhost/static/audio/sound_nt.mp3",
        exercises=["tent", "paint"],
    ),
    dict(
        id=63,
        symbol="lt",
        unit="UNIT6",
        lesson=5,
        type="letter combination",
        description="Final consonant cluster /lt/ as in 'belt'.",
        audio_url="http://localhost/static/audio/sound_lt.mp3",
        exercises=["belt"],
    ),
    dict(
        id=64,
        symbol="mp",
        unit="UNIT6",
        lesson=6,
        type="letter combination",
        description="Final consonant cluster /mp/ as in 'lamp' and 'camp'.",
        audio_url="http://localhost/static/audio/sound_mp.mp3",
        exercises=["lamp", "camp"],
    ),
    dict(
        id=80,
        symbol="ə (schwa)",
        unit="UNIT6",
        lesson=1,
        type="schwa",
        description="Schwa /ə/, the unstressed vowel in many English words.",
        audio_url="http://localhost/static/audio/sound_schwa.mp3",
        exercises=[
            "panda",
            "gorilla",
            "banana",
            "umbrella",
            "chicken",
            "pencil",
            "lemon",
            "surprise",
            "monkey",
            "love",
            "son",
            "honey",
        ],
    ),
    # ── UNIT 7 ──────────────────────────────────────────────────────────────
    dict(
        id=19,
        symbol="s",
        unit="UNIT7",
        lesson=1,
        type="alphabet",
        description="Voiceless alveolar fricative /s/ as in 'seal', written with S.",
        audio_url="http://localhost/static/audio/sound_s.mp3",
        exercises=["seal", "sun", "soap", "socks"],
    ),
    dict(
        id=20,
        symbol="t",
        unit="UNIT7",
        lesson=2,
        type="alphabet",
        description="Voiceless alveolar plosive /t/ as in 'turtle', written with T.",
        audio_url="http://localhost/static/audio/sound_t.mp3",
        exercises=["turtle", "tent", "tiger", "teacher"],
    ),
    dict(
        id=21,
        symbol="ʌ/ə",
        unit="UNIT7",
        lesson=3,
        type="alphabet",
        description="Short u sound as in 'umbrella', written with U.",
        audio_url="http://localhost/static/audio/sound_u.mp3",
        exercises=["umbrella", "up", "uncle", "umpire"],
    ),
    dict(
        id=22,
        symbol="v",
        unit="UNIT7",
        lesson=4,
        type="alphabet",
        description="Voiced labiodental fricative /v/ as in 'van', written with V.",
        audio_url="http://localhost/static/audio/sound_v.mp3",
        exercises=["van", "vet", "vest", "violin"],
    ),
    dict(
        id=65,
        symbol="sk",
        unit="UNIT7",
        lesson=1,
        type="consonant blend",
        description="Consonant blend /sk/ as in 'skunk' and 'desk'.",
        audio_url="http://localhost/static/audio/sound_sk.mp3",
        exercises=["skunk", "desk"],
    ),
    dict(
        id=66,
        symbol="sc",
        unit="UNIT7",
        lesson=2,
        type="consonant blend",
        description="Blend sc pronounced /sk/ as in 'scale' and 'school'.",
        audio_url="http://localhost/static/audio/sound_sc.mp3",
        exercises=["scale", "school"],
    ),
    dict(
        id=67,
        symbol="spr",
        unit="UNIT7",
        lesson=3,
        type="consonant blend",
        description="Consonant blend /spr/ as in 'spray' and 'spring'.",
        audio_url="http://localhost/static/audio/sound_spr.mp3",
        exercises=["spray", "spring"],
    ),
    dict(
        id=68,
        symbol="str",
        unit="UNIT7",
        lesson=4,
        type="consonant blend",
        description="Consonant blend /str/ as in 'string' and 'strong'.",
        audio_url="http://localhost/static/audio/sound_str.mp3",
        exercises=["string", "strong"],
    ),
    dict(
        id=69,
        symbol="spl",
        unit="UNIT7",
        lesson=5,
        type="consonant blend",
        description="Consonant blend /spl/ as in 'splash' and 'splint'.",
        audio_url="http://localhost/static/audio/sound_spl.mp3",
        exercises=["splash", "splint"],
    ),
    dict(
        id=70,
        symbol="skw (squ)",
        unit="UNIT7",
        lesson=6,
        type="consonant blend",
        description="Consonant blend /skw/ spelled squ as in 'squid' and 'square'.",
        audio_url="http://localhost/static/audio/sound_squ.mp3",
        exercises=["squid", "square"],
    ),
    dict(
        id=81,
        symbol="kn- (silent k)",
        unit="UNIT7",
        lesson=1,
        type="silent letters",
        description="Silent k in kn at the start of words, pronounced /n/.",
        audio_url="http://localhost/static/audio/sound_kn.mp3",
        exercises=["knife", "knee"],
    ),
    dict(
        id=82,
        symbol="wr- (silent w)",
        unit="UNIT7",
        lesson=2,
        type="silent letters",
        description="Silent w in wr at the start of words, pronounced /r/.",
        audio_url="http://localhost/static/audio/sound_wr.mp3",
        exercises=["write", "wrong"],
    ),
    dict(
        id=83,
        symbol="mb (silent b)",
        unit="UNIT7",
        lesson=3,
        type="silent letters",
        description="Final mb where b is silent, pronounced /m/.",
        audio_url="http://localhost/static/audio/sound_mb.mp3",
        exercises=["lamb", "comb"],
    ),
    dict(
        id=84,
        symbol="rh- (silent h)",
        unit="UNIT7",
        lesson=4,
        type="silent letters",
        description="Initial rh pronounced /r/, h silent.",
        audio_url="http://localhost/static/audio/sound_rh.mp3",
        exercises=["rhino", "rhubarb"],
    ),
    dict(
        id=85,
        symbol="st (silent t in some words)",
        unit="UNIT7",
        lesson=5,
        type="silent letters",
        description="Silent t in some st words like 'castle'.",
        audio_url="http://localhost/static/audio/sound_st_silent_t.mp3",
        exercises=["castle", "whistle"],
    ),
    # ── UNIT 8 ──────────────────────────────────────────────────────────────
    dict(
        id=23,
        symbol="w",
        unit="UNIT8",
        lesson=1,
        type="alphabet",
        description="Approximant /w/ as in 'wolf', written with W.",
        audio_url="http://localhost/static/audio/sound_w.mp3",
        exercises=["wolf", "web", "water", "watch"],
    ),
    dict(
        id=24,
        symbol="ks",
        unit="UNIT8",
        lesson=2,
        type="alphabet",
        description="Consonant cluster /ks/ as in 'fox', written with X.",
        audio_url="http://localhost/static/audio/sound_x.mp3",
        exercises=["fox", "box", "six", "wax"],
    ),
    dict(
        id=25,
        symbol="j",
        unit="UNIT8",
        lesson=3,
        type="alphabet",
        description="Palatal approximant /j/ as in 'yo-yo', written with Y.",
        audio_url="http://localhost/static/audio/sound_y.mp3",
        exercises=["yo-yo", "yak", "yogurt", "yacht"],
    ),
    dict(
        id=26,
        symbol="z",
        unit="UNIT8",
        lesson=4,
        type="alphabet",
        description="Voiced alveolar fricative /z/ as in 'zebra', written with Z.",
        audio_url="http://localhost/static/audio/sound_z.mp3",
        exercises=["zipper", "zero", "zoo", "zebra"],
    ),
    dict(
        id=71,
        symbol="s (voiced)",
        unit="UNIT8",
        lesson=3,
        type="letter combination",
        description="Voiced /z/ sound spelled s in words like 'rose' and 'jeans'.",
        audio_url="http://localhost/static/audio/sound_voiced_s.mp3",
        exercises=["rose", "jeans", "cheese", "legs"],
    ),
    dict(
        id=86,
        symbol="tʃər (ture)",
        unit="UNIT8",
        lesson=1,
        type="suffix",
        description="Ending -ture pronounced /tʃər/ as in 'picture' and 'nature'.",
        audio_url="http://localhost/static/audio/sound_ture.mp3",
        exercises=["picture", "nature"],
    ),
    dict(
        id=87,
        symbol="ʒər (sure)",
        unit="UNIT8",
        lesson=2,
        type="suffix",
        description="Ending -sure pronounced /ʒər/ as in 'treasure' and 'measure'.",
        audio_url="http://localhost/static/audio/sound_sure.mp3",
        exercises=["treasure", "measure"],
    ),
    dict(
        id=88,
        symbol="ʃən (tion/sion)",
        unit="UNIT8",
        lesson=3,
        type="suffix",
        description="Endings -tion/-sion pronounced /ʃən/ as in 'station'.",
        audio_url="http://localhost/static/audio/sound_tion_sion.mp3",
        exercises=["station", "competition", "television", "excursion"],
    ),
    dict(
        id=89,
        symbol="əs (ous)",
        unit="UNIT8",
        lesson=4,
        type="suffix",
        description="Suffix -ous pronounced /əs/ as in 'dangerous' and 'famous'.",
        audio_url="http://localhost/static/audio/sound_ous.mp3",
        exercises=["famous", "dangerous"],
    ),
    dict(
        id=90,
        symbol="fəl (ful)",
        unit="UNIT8",
        lesson=5,
        type="suffix",
        description="Suffix -ful pronounced /fəl/ as in 'beautiful' and 'helpful'.",
        audio_url="http://localhost/static/audio/sound_ful.mp3",
        exercises=["beautiful", "helpful"],
    ),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def get_or_create_lesson(
    db: AsyncSession,
    unit: str,
    lesson_number: int,
) -> Lesson:
    level = UNIT_LEVEL_MAP[unit]
    order = UNIT_ORDER_BASE[unit] + lesson_number

    result = await db.execute(
        select(Lesson).where(Lesson.order == order, Lesson.level == level)
    )
    lesson = result.scalar_one_or_none()
    if not lesson:
        lesson = Lesson(order=order, level=level)
        db.add(lesson)
        await db.flush()  # get the ID without committing yet
        log.info(
            "  Created lesson: %s lesson %d (order=%d, level=%s)",
            unit,
            lesson_number,
            order,
            level.value,
        )
    return lesson


async def get_or_create_phoneme(
    db: AsyncSession,
    data: dict,
    lesson: Lesson,
    global_order: int,
) -> Optional[Phoneme]:
    result = await db.execute(select(Phoneme).where(Phoneme.symbol == data["symbol"]))
    phoneme = result.scalar_one_or_none()
    if not phoneme:
        phoneme_type = PHONEME_TYPE_MAP.get(data["type"])
        if phoneme_type is None:
            log.warning(
                "  Unknown phoneme type '%s' for symbol '%s' — skipping",
                data["type"],
                data["symbol"],
            )
            return None

        phoneme = Phoneme(
            symbol=data["symbol"],
            description=data["description"],
            audio_url=data["audio_url"],
            lesson_id=lesson.id,
            order=global_order,
            type=phoneme_type,
        )
        db.add(phoneme)
        await db.flush()
        log.info(
            "  Created phoneme: /%s/ (order=%d, type=%s)",
            data["symbol"],
            global_order,
            phoneme_type.value,
        )
    else:
        log.info("  Phoneme /%s/ already exists — skipping", data["symbol"])
    return phoneme


async def seed_exercises(
    db: AsyncSession,
    phoneme: Phoneme,
    word_list: list[str],
) -> None:
    for word in word_list:
        # Check if exercise already exists to avoid duplicates
        result = await db.execute(
            select(Exercise).where(
                Exercise.content == word,
                Exercise.lesson_id == phoneme.lesson_id,
            )
        )
        existing = result.scalar_one_or_none()
        if not existing:
            exercise = Exercise(
                lesson_id=phoneme.lesson_id,
                content=word,
                type=ExerciseType.WORD,
                difficulty=1,
            )
            exercise.phonemes = [phoneme]
            db.add(exercise)


# ---------------------------------------------------------------------------
# Main seed function
# ---------------------------------------------------------------------------


async def seed() -> None:
    log.info("Starting phoneme seed...")
    log.info("Total phonemes to process: %d", len(PHONEMES))

    async with AsyncSessionLocal() as db:
        # Assign a global order to each phoneme.
        # We sort by (unit number, lesson number, original JSON id)
        # so the ordering rule works correctly across the full curriculum.
        sorted_phonemes = sorted(
            PHONEMES,
            key=lambda p: (
                int(p["unit"].replace("UNIT", "")),
                p["lesson"],
                p["id"],
            ),
        )

        for global_order, data in enumerate(sorted_phonemes, start=1):
            log.info(
                "Processing [%d/90]: /%s/ (%s %s)",
                global_order,
                data["symbol"],
                data["unit"],
                data["lesson"],
            )

            lesson = await get_or_create_lesson(db, data["unit"], data["lesson"])
            phoneme = await get_or_create_phoneme(db, data, lesson, global_order)

            if phoneme:
                await seed_exercises(db, phoneme, data["exercises"])

        await db.commit()

    log.info("")
    log.info("✅ Seed complete!")
    log.info("   Phonemes : up to 90 created")
    log.info("   Lessons  : up to 42 created (8 units × up to 6 lessons)")
    log.info("   Exercises: initial word exercises seeded for each phoneme")
    log.info("")
    log.info(
        "NOTE: audio_url values are placeholders (http://localhost/static/audio/*.mp3)."
    )
    log.info("Replace them with real URLs once audio files are uploaded to the server.")


if __name__ == "__main__":
    asyncio.run(seed())
