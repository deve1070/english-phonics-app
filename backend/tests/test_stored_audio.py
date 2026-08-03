"""What a stored audio url is allowed to point at.

These strings come out of database columns and are handed to unlink().
Every value in there today was written by save_audio_file, but "today"
is not a guarantee worth resting a delete on, and the failure mode if it
stops being true is removing a file somewhere else on the machine.
"""

from pathlib import Path

from app.utils.audio import UPLOAD_DIR, delete_audio_file, resolve_stored_audio

ROOT = Path(UPLOAD_DIR).parent.resolve()


def test_an_ordinary_stored_url_resolves_under_uploads():
    path = resolve_stored_audio("/audio/0aae6aec-b452-43bb-8e19-f4591b44cd4c.mp3")

    assert path is not None
    assert path == ROOT / "audio" / "0aae6aec-b452-43bb-8e19-f4591b44cd4c.mp3"


def test_a_url_without_its_leading_slash_still_resolves():
    # phonemes.py already reads both shapes out of this column.
    assert resolve_stored_audio("audio/x.mp3") == ROOT / "audio" / "x.mp3"


def test_nothing_escapes_the_uploads_directory():
    for hostile in [
        "/audio/../../etc/passwd",
        "../../.env",
        "/audio/../../../../../../etc/hosts",
        "/../backend/.env",
    ]:
        assert resolve_stored_audio(hostile) is None, hostile


def test_an_empty_url_is_not_a_file():
    assert resolve_stored_audio("") is None
    assert delete_audio_file("") is False


def test_deleting_is_never_an_exception(tmp_path):
    # Housekeeping runs after a parent has been told their recording was
    # saved. It must not be able to turn that into an error.
    assert delete_audio_file("/audio/there-is-no-such-file.mp3") is False
    assert delete_audio_file("/audio/../../etc/passwd") is False


def test_a_real_file_is_removed():
    target = ROOT / "audio" / "test-delete-me.mp3"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(b"\xff\xfb\x90\x00")

    assert delete_audio_file("/audio/test-delete-me.mp3") is True
    assert not target.exists()
