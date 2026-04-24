from .base import CRUDBase
from .crud_phoneme import crud_phoneme
from .crud_pronunciation_score import crud_pronunciation_score
from .users import crud as _user_crud


class _CRUDProxy:
    def __init__(self, user_crud, phoneme_crud):
        self.user = user_crud
        self.phoneme = phoneme_crud
        self.pronunciation_score = crud_pronunciation_score

    def __getattr__(self, name):
        # Delegate attribute access to the user CRUD so both
        # `crud.get_multi(...)` and `crud.user.create(...)` work.
        return getattr(self.user, name)


# export a proxy that supports crud.user, crud.phoneme, and crud.get_multi etc.
crud = _CRUDProxy(_user_crud, crud_phoneme)
pronunciation_score = crud_pronunciation_score


# also expose `user` and `phoneme` so `from app import crud` then `crud.phoneme` works (crud is the module)
user = _user_crud
phoneme = crud_phoneme

__all__ = ["crud", "user", "phoneme"]
