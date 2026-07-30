"""
Organize pre-recorded phoneme files.
Renames files from uploads/audio/ to uploads/audio_standardized/ with IPA-based naming.
"""

import os
import shutil
from pathlib import Path

# Mapping from current filenames to IPA symbols
PHONEME_FILE_MAPPING = {
    "sound_a.mp3": "phoneme_æ.mp3",
    "sound_ai.mp3": "phoneme_eɪ.mp3",
    "sound_ar.mp3": "phoneme_ɑːr.mp3",
    "sound_b.mp3": "phoneme_b.mp3",
    "sound_ch.mp3": "phoneme_tʃ.mp3",
    "sound_ck.mp3": "phoneme_k.mp3",
    "sound_d.mp3": "phoneme_d.mp3",
    "sound_e.mp3": "phoneme_ɛ.mp3",
    "sound_ee.mp3": "phoneme_iː.mp3",
    "sound_er.mp3": "phoneme_ər.mp3",
    "sound_f.mp3": "phoneme_f.mp3",
    "sound_g.mp3": "phoneme_ɡ.mp3",
    "sound_h.mp3": "phoneme_h.mp3",
    "sound_i.mp3": "phoneme_ɪ.mp3",
    "sound_ie.mp3": "phoneme_aɪ.mp3",
    "sound_j.mp3": "phoneme_dʒ.mp3",
    "sound_k.mp3": "phoneme_k.mp3",
    "sound_l.mp3": "phoneme_l.mp3",
    "sound_longa.mp3": "phoneme_eɪ.mp3",
    "sound_m.mp3": "phoneme_m.mp3",
    "sound_n.mp3": "phoneme_n.mp3",
    "sound_ng.mp3": "phoneme_ŋ.mp3",
    "sound_o.mp3": "phoneme_ɒ.mp3",
    "sound_oa.mp3": "phoneme_oʊ.mp3",
    "sound_oi.mp3": "phoneme_ɔɪ.mp3",
    "sound_oo.mp3": "phoneme_ʊ.mp3",
    "sound_ooo.mp3": "phoneme_uː.mp3",
    "sound_or.mp3": "phoneme_ɔːr.mp3",
    "sound_ou.mp3": "phoneme_aʊ.mp3",
    "sound_p.mp3": "phoneme_p.mp3",
    "sound_qu.mp3": "phoneme_kw.mp3",
    "sound_r.mp3": "phoneme_r.mp3",
    "sound_s.mp3": "phoneme_s.mp3",
    "sound_sh.mp3": "phoneme_ʃ.mp3",
    "sound_t.mp3": "phoneme_t.mp3",
    "sound_th.mp3": "phoneme_θ.mp3",
    "sound_thh.mp3": "phoneme_ð.mp3",
    "sound_u.mp3": "phoneme_ʌ.mp3",
    "sound_ue.mp3": "phoneme_uː.mp3",
    "sound_v.mp3": "phoneme_v.mp3",
    "sound_w.mp3": "phoneme_w.mp3",
    "sound_x.mp3": "phoneme_ks.mp3",
    "sound_y.mp3": "phoneme_j.mp3",
    "sound_z.mp3": "phoneme_z.mp3",
}

def organize_phoneme_files():
    """Copy and rename phoneme files to audio_standardized directory."""
    source_dir = Path("/home/dmk/english-phonics-app/backend/uploads/audio")
    target_dir = Path("/home/dmk/english-phonics-app/backend/uploads/audio_standardized")
    
    if not source_dir.exists():
        print(f"Source directory {source_dir} does not exist")
        return
    
    target_dir.mkdir(parents=True, exist_ok=True)
    
    copied_count = 0
    skipped_count = 0
    
    for old_name, new_name in PHONEME_FILE_MAPPING.items():
        source_path = source_dir / old_name
        target_path = target_dir / new_name
        
        if source_path.exists():
            shutil.copy2(source_path, target_path)
            print(f"Copied: {old_name} -> {new_name}")
            copied_count += 1
        else:
            print(f"Skipped (not found): {old_name}")
            skipped_count += 1
    
    print(f"\nSummary: {copied_count} files copied, {skipped_count} files skipped")

if __name__ == "__main__":
    organize_phoneme_files()
