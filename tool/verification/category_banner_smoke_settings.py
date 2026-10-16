"""Isolated local-only settings for category advertisement walkthroughs."""
import os
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[2]
SMOKE_ROOT = Path(os.environ["CATEGORY_BANNER_SMOKE_ROOT"]).resolve()
if not SMOKE_ROOT.is_relative_to(APP_ROOT / "build/category-banner-smoke"):
    raise RuntimeError("Smoke data must stay in build/category-banner-smoke")

os.environ.update({
    "DEBUG": "1", "SECRET_KEY": "isolated-category-banner-walkthrough-only",
    "DATABASE_URL": f"sqlite:///{SMOKE_ROOT / 'db.sqlite3'}",
    "SMS_ENABLED": "0", "REDIS_URL": "", "CACHE_REDIS_URL": "",
    "USE_OBJECT_STORAGE": "0", "ANDROID_UPDATE_ENABLED": "0",
    "TELEGRAM_NOTIFICATION_BOT_TOKEN": "", "CUSTOMER_PUSH_ENABLED": "0",
    "COURIER_PUSH_ENABLED": "0", "COURIER_BROADCAST_PUSH_ENABLED": "0",
})

from config.settings import *  # noqa: F403,E402

TESTING = True
ALLOWED_HOSTS = ["127.0.0.1", "localhost", "testserver"]
CORS_ALLOW_ALL_ORIGINS = True
DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": SMOKE_ROOT / "db.sqlite3"}}
CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache", "LOCATION": "isolated-category-banner-smoke"}}
CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}
MEDIA_ROOT = SMOKE_ROOT / "media"
MEDIA_URL = "/media/"
STORAGES = {"default": {"BACKEND": "django.core.files.storage.FileSystemStorage"}, "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"}, "private_support": {"BACKEND": "django.core.files.storage.FileSystemStorage", "OPTIONS": {"location": str(SMOKE_ROOT / "private-support")}}}
STORAGES["private_video_source"] = {"BACKEND": "django.core.files.storage.FileSystemStorage", "OPTIONS": {"location": str(SMOKE_ROOT / "private-video")}}
CELERY_BROKER_URL = "memory://"
CELERY_RESULT_BACKEND = "cache+memory://"
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True
SMS_ENABLED = False
TEST_OTP_ACCOUNTS = {}
LOGGING = {"version": 1, "disable_existing_loggers": False, "handlers": {"console": {"class": "logging.StreamHandler"}}, "root": {"handlers": ["console"], "level": "WARNING"}}
