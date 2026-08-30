CREATE TABLE IF NOT EXISTS charging_operators (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    operator_code TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    search_aliases_json TEXT NOT NULL DEFAULT '[]',
    country_code TEXT NOT NULL DEFAULT 'TR',
    tier INTEGER NOT NULL DEFAULT 3,
    station_count_estimate INTEGER,
    station_count_confidence TEXT,
    supports_roaming INTEGER,
    app_required INTEGER NOT NULL DEFAULT 1,
    is_active INTEGER NOT NULL DEFAULT 1,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    favorite_order INTEGER,
    is_hidden INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER NOT NULL DEFAULT 9999,
    source_basis TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_charging_operators_sort_order
ON charging_operators(sort_order);

CREATE INDEX IF NOT EXISTS idx_charging_operators_tier
ON charging_operators(tier);

CREATE INDEX IF NOT EXISTS idx_charging_operators_favorite
ON charging_operators(is_favorite, favorite_order);

CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
