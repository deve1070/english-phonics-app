from fastapi import FastAPI
from app.main import app


def test_app_importable():
    assert isinstance(app, FastAPI)
