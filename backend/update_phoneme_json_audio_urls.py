import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PHONEME_JSON = ROOT / "phoneme.json"
AUDIO_DIR = ROOT / "uploads" / "audio_standardized"


SYMBOL_TO_FILE = {
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
    "eɪ (a_e)": "phoneme_a_long.mp3",
    "aɪ (i_e)": "phoneme_ie.mp3",
    "oʊ (o_e)": "phoneme_o_long.mp3",
    "uː (u_e)": "phoneme_u_long.mp3",
    "eɪ (ai)": "phoneme_ai.mp3",
    "eɪ (ay)": "phoneme_ai.mp3",
    "iː (ee/ea)": "phoneme_ee.mp3",
    "bl": "phoneme_b.mp3",
    "cl": "phoneme_k.mp3",
    "br": "phoneme_b.mp3",
    "cr": "phoneme_k.mp3",
    "fl": "phoneme_f.mp3",
    "gl": "phoneme_g.mp3",
    "fr": "phoneme_f.mp3",
    "gr": "phoneme_g.mp3",
    "pl": "phoneme_p.mp3",
    "sl": "phoneme_s.mp3",
    "dr": "phoneme_d.mp3",
    "tr": "phoneme_t.mp3",
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
    "fəl (ful)": "phoneme_f.mp3",
}


def normalize_symbol(symbol: str) -> str:
    return re.sub(r"\s+", " ", (symbol or "").strip())


def main() -> None:
    available = {p.name for p in AUDIO_DIR.glob("*.mp3")}
    with PHONEME_JSON.open("r", encoding="utf-8") as f:
        data = json.load(f)

    updated = 0
    missing = []
    for item in data.get("phonemes", []):
        symbol = normalize_symbol(item.get("symbol", ""))
        filename = SYMBOL_TO_FILE.get(symbol)
        if filename and filename in available:
            item["audio_url"] = f"/audio_standardized/{filename}"
            updated += 1
        else:
            item["audio_url"] = None
            missing.append(symbol)

    with PHONEME_JSON.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Updated audio_url for {updated} phonemes.")
    if missing:
        print(f"Set audio_url=null for {len(missing)} phonemes without mapping.")


if __name__ == "__main__":
    main()
