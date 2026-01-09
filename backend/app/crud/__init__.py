from .base import CRUDBase
from .users import crud as _user_crud
from types import SimpleNamespace

class _CRUDProxy:
    def __init__(self, user_crud):
        self.user = user_crud

    def __getattr__(self, name):
        # Delegate attribute access to the user CRUD instance so both
        # `crud.get_multi(...)` and `crud.user.create(...)` work.
        return getattr(self.user, name)

# export a proxy that supports both patterns used in the codebase
crud = _CRUDProxy(_user_crud)

# also expose `user` directly if code does `from app.crud import user`
user = _user_crud

__all__ = ["crud", "user"]
