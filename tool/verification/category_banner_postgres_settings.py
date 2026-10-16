"""Migration-only validation against an explicitly supplied scratch PostgreSQL DB."""

import os

import dj_database_url

from category_banner_smoke_settings import *  # noqa: F403

DATABASES = {
    "default": dj_database_url.parse(os.environ["CATEGORY_BANNER_SMOKE_POSTGRES_URL"])
}
