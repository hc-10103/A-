import copy
import json
from datetime import datetime
from pathlib import Path

import pytest

from app.data_sources import KST

FIXTURE = Path(__file__).parent / "fixtures" / "citydata_sample.json"
# 픽스처를 받은 시각 (WEATHER_TIME 19:30, PPLTN_TIME 19:05)
FIXTURE_NOW = datetime(2026, 11, 23, 19, 35, tzinfo=KST)


@pytest.fixture(autouse=True)
def _no_real_network_keys(monkeypatch):
    """로컬 .env 에 실제 키가 있어도 테스트가 외부 API 를 부르지 않게 한다."""
    monkeypatch.delenv("DATA_GO_KR_API_KEY", raising=False)
    monkeypatch.delenv("KOPIS_API_KEY", raising=False)
    from app import data_sources as ds

    ds._cache.clear()
    from app import kopis

    kopis._cache.clear()


@pytest.fixture
def citydata() -> dict:
    return copy.deepcopy(json.loads(FIXTURE.read_text(encoding="utf-8")))


@pytest.fixture
def fixture_now() -> datetime:
    return FIXTURE_NOW
