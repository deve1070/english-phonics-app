from app.crud.base import CRUDBase
from app.models.phoneme import Phoneme
from app.schemas.phoneme import PhonemeCreate, PhonemeUpdate

crud_phoneme = CRUDBase[Phoneme, PhonemeCreate, PhonemeUpdate](Phoneme)
