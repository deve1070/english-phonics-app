import asyncio
import os
import re
from app.db.session import AsyncSessionLocal
from app.models.phoneme import Phoneme
from sqlalchemy import select

# Hand-crafted precise mapping matching update_phoneme_json_audio_urls.py
SYMBOL_TO_FILE = {
    # Short Vowels
    "a": "phoneme_a_short.mp3",
    "b": "phoneme_b.mp3",
    "k": "phoneme_k.mp3",
    "d": "phoneme_d.mp3",
    "e": "phoneme_e_short.mp3",
    "f": "phoneme_f.mp3",
    "g": "phoneme_g.mp3",
    "h": "phoneme_h.mp3",
    "ɪ": "phoneme_i_short.mp3",
    "dʒ": "phoneme_j.mp3",
    "kʰ": "phoneme_k.mp3",
    "l": "phoneme_l.mp3",
    "m": "phoneme_m.mp3",
    "n": "phoneme_n.mp3",
    "ɒ/ɔ": "phoneme_o_short.mp3",
    "p": "phoneme_p.mp3",
    "kw": "phoneme_qu.mp3",
    "r": "phoneme_r.mp3",
    "s": "phoneme_s.mp3",
    "t": "phoneme_t.mp3",
    "ʌ/ə": "phoneme_u_short.mp3",
    "v": "phoneme_v.mp3",
    "w": "phoneme_w.mp3",
    "ks": "phoneme_x.mp3",
    "j": "phoneme_y.mp3",
    "z": "phoneme_z.mp3",
    
    # Long Vowels & Spelled Digraphs
    "eɪ (a_e)": "phoneme_a_long.mp3",
    "aɪ (i_e)": "phoneme_ie.mp3",
    "oʊ (o_e)": "phoneme_o_long.mp3",
    "uː (u_e)": "phoneme_u_long.mp3",
    "eɪ (ai)": "phoneme_ai.mp3",
    "eɪ (ay)": "phoneme_ai.mp3",
    "iː (ee/ea)": "phoneme_ee.mp3",

    # Consonant Blends
    "bl": "phoneme_bl.mp3",
    "cl": "phoneme_cl.mp3",
    "br": "phoneme_br.mp3",
    "cr": "phoneme_cr.mp3",
    "fl": "phoneme_fl.mp3",
    "gl": "phoneme_gl.mp3",
    "fr": "phoneme_fr.mp3",
    "gr": "phoneme_gr.mp3",
    "pl": "phoneme_pl.mp3",
    "sl": "phoneme_sl.mp3",
    "dr": "phoneme_dr.mp3",
    "tr": "phoneme_tr.mp3",

    # Soft Blends & Digraphs
    "sh": "phoneme_sh.mp3",
    "ʃ (sh)": "phoneme_sh.mp3",
    "ch": "phoneme_ch.mp3",
    "tʃ (ch)": "phoneme_ch.mp3",
    "ph": "phoneme_f.mp3",
    "f (ph)": "phoneme_f.mp3",
    "wh": "phoneme_w.mp3",
    "w (wh)": "phoneme_w.mp3",
    "th (voiced)": "phoneme_thh.mp3",
    "ð (voiced th)": "phoneme_thh.mp3",
    "th (unvoiced)": "phoneme_th.mp3",
    "θ (unvoiced th)": "phoneme_th.mp3",
    "ck": "phoneme_ck.mp3",
    "qu": "phoneme_qu.mp3",
    "ar": "phoneme_ar.mp3",
    "ɜːr (ir/ur)": "phoneme_er.mp3",
    "ər (er/or)": "phoneme_er.mp3",
    "aʊ (ou/ow)": "phoneme_ou.mp3",
    "ɔɪ (oi/oy)": "phoneme_oi.mp3",
    "ʊ/ʌ (oo/u)": "phoneme_oo.mp3",
    "ɔː (au/aw)": "phoneme_au.mp3",
    "ɔː (or/oar)": "phoneme_or.mp3",
    "ŋ": "phoneme_ng.mp3",
    "ŋ (ng)": "phoneme_ng.mp3",
    "nk": "phoneme_ng.mp3",
    "nd": "phoneme_n.mp3",
    "nt": "phoneme_n.mp3",
    "lt": "phoneme_l.mp3",
    "mp": "phoneme_m.mp3",
    "sm": "phoneme_s.mp3",
    "sn": "phoneme_s.mp3",
    "sp": "phoneme_s.mp3",
    "sw": "phoneme_s.mp3",
    "st": "phoneme_s.mp3",
    "sk": "phoneme_s.mp3",
    "sc": "phoneme_s.mp3",
    "spr": "phoneme_s.mp3",
    "str": "phoneme_s.mp3",
    "spl": "phoneme_s.mp3",
    "squ": "phoneme_s.mp3",
    "skw (squ)": "phoneme_s.mp3",
    "ə (schwa)": "phoneme_e_short.mp3",
    "kn- (silent k)": "phoneme_n.mp3",
    "wr- (silent w)": "phoneme_r.mp3",
    "mb (silent b)": "phoneme_m.mp3",
    "rh- (silent h)": "phoneme_r.mp3",
    "st (silent t)": "phoneme_s.mp3",
    "st (silent t in some words)": "phoneme_s.mp3",
    "z (voiced s)": "phoneme_z.mp3",
    "s (voiced)": "phoneme_z.mp3",
    "tʃər (ture)": "phoneme_ch.mp3",
    "ʒər (sure)": "phoneme_sh.mp3",
    "ʃən (tion/sion)": "phoneme_sh.mp3",
    "əs (ous)": "phoneme_s.mp3",
    "fəl (ful)": "phoneme_f.mp3"
}

def normalize_symbol(symbol: str) -> str:
    return re.sub(r"\s+", " ", (symbol or "").strip())

async def main():
    directory = "uploads/audio_standardized"
    if not os.path.exists(directory):
        print(f"Directory {directory} not found")
        return
        
    available_files = {f for f in os.listdir(directory) if f.endswith('.mp3')}
    
    async with AsyncSessionLocal() as session:
        result = await session.execute(select(Phoneme))
        phonemes = result.scalars().all()
        
        updated_count = 0
        for p in phonemes:
            symbol = normalize_symbol(p.symbol)
            filename = SYMBOL_TO_FILE.get(symbol)
            
            if filename and filename in available_files:
                p.audio_url = f"/audio_standardized/{filename}"
                updated_count += 1
                print(f"Mapped '{p.symbol}' -> {filename}")
            else:
                p.audio_url = None
                print(f"NO MAPPING for '{p.symbol}'")
                
        await session.commit()
        print(f"Updated {updated_count} phonemes.")

if __name__ == "__main__":
    asyncio.run(main())
