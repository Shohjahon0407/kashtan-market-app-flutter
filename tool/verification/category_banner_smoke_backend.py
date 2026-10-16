"""Seed and serve actual Django APIs against a dedicated smoke database only.

Run with backend .venv Python and CATEGORY_BANNER_SMOKE_ROOT set to a new build directory.
No existing database, Redis, media, SMS or production API is used.
"""
import json
import os
from pathlib import Path
import sys

APP_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(APP_ROOT.parent / "backend"))
os.environ["DJANGO_SETTINGS_MODULE"] = "category_banner_smoke_settings"
from category_banner_smoke_settings import SMOKE_ROOT

SMOKE_ROOT.mkdir(parents=True, exist_ok=True)
import django
django.setup()

from django.core.management import call_command
from django.conf import settings
from django.apps import apps
from django.core.files import File
from apps.accounts.models import User
from apps.catalog.models import Category, Product, ProductImage
from apps.stores.models import Store
from apps.promotions.models import CategoryProductBanner

if not (SMOKE_ROOT / "seed.json").exists():
    # The production migration graph contains PostgreSQL-only concurrent
    # indexes. Sync real current models to this disposable SQLite database;
    # production migration validation is a separate parent-agent test step.
    settings.MIGRATION_MODULES = {app.label: None for app in apps.get_app_configs()}
    call_command("migrate", run_syncdb=True, interactive=False, verbosity=0)
    User.objects.create_superuser(phone_number="+998900000001", password="LocalSmokeOnly-2026", first_name="Mahalliy", last_name="Sinov")
    store = Store.objects.create(name_uz="Xozmak", name_ru="Xozmak", store_type="household")
    categories = []
    for index, name in enumerate(["Qurilish mollari", "Ustachilik asboblari", "Elektronika"]):
        categories.append(Category.objects.create(name_uz=name, name_ru=name, store_type="household", sort_order=index))
    rows = [
        (0, "Mustahkam qurilish to‘plami", "construction.webp", "145000"),
        (0, "Uy ta’miri uchun qurilish mollari", "construction.webp", "89000"),
        (0, "Qurilish uchun mahkamlash to‘plami", "construction.webp", "35000"),
        (1, "Professional ustachilik to‘plami", "tools.webp", "249000"),
        (1, "Qulay bolg‘a va qo‘l asboblari", "tools.webp", "119000"),
        (2, "Simsiz quloqchin va elektronika", "electronics.webp", "199000"),
    ]
    products = []
    for cat, name, asset, price in rows:
        product = Product.objects.create(store=store, category=categories[cat], name_uz=name, price=price, product_type="household", stock_quantity=50, is_available=True, is_popular=True)
        photo = ProductImage(product=product, is_main=True)
        with (APP_ROOT / "assets/categories/household" / asset).open("rb") as handle:
            photo.image.save(asset, File(handle), save=True)
        products.append(product)
    CategoryProductBanner.objects.create(category=categories[0], product=products[0], title_uz="Ta’mirni ishonch bilan boshlang", subtitle_uz="Uyingiz uchun kerakli qurilish mollari bir joyda", badge_uz="Hafta tanlovi", cta_uz="Batafsil ko‘rish", background_color="#087F65", sort_order=0)
    CategoryProductBanner.objects.create(category=categories[0], product=products[1], title_uz="Har bir ishga mos yechim", subtitle_uz="Qurilish va ta’mirlash uchun qulay tanlov", badge_uz="Siz uchun", cta_uz="Mahsulotni ko‘rish", background_color="#1B4263", sort_order=1)
    CategoryProductBanner.objects.create(category=categories[1], product=products[3], title_uz="Ustalar uchun ishonchli asboblar", subtitle_uz="Kundalik ish uchun qulay to‘plam", badge_uz="Tavsiya etamiz", cta_uz="Xarid qilish", background_color="#554077", sort_order=0)
    (SMOKE_ROOT / "seed.json").write_text(json.dumps({"categories": [{"id": str(c.id), "name": c.name_uz} for c in categories], "products": [{"id": str(p.id), "name": p.name_uz} for p in products]}, ensure_ascii=False, indent=2))
    print("Isolated smoke data ready", flush=True)

call_command("runserver", "127.0.0.1:8877", use_reloader=False, verbosity=0)
