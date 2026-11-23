import copy
import json
from datetime import datetime
from pathlib import Path

import pytest

from app.data_sources import KST

FIXTURE = Path(__file__).parent / "fixtures" / "citydata_sample.json"
# 픽스처를 받은 시각 (WEATHER_TIME 19:30, PPLTN_TIME 19:05)
FIXTURE_NOW = datetime(2026, 11, 23, 19, 35, tzinfo=KST)


@pytest.fixture
def citydata() -> dict:
    return copy.deepcopy(json.loads(FIXTURE.read_text(encoding="utf-8")))


@pytest.fixture
def fixture_now() -> datetime:
    return FIXTURE_NOW
