-- ─────────────────────────────────────────────────────────────────────────────
--  crp_jobcore – struktura bazy (bossmenu + przebieralnia)
--
--  Zasób zakłada te tabele sam przy pierwszym starcie (s_data.lua → data.Install,
--  s_wardrobe.lua → CREATE TABLE przy starcie), a data.AlignSchema dokłada brakujące
--  kolumny w tabelach po starszej wersji. Ten plik jest dla wygody: możesz go wgrać
--  ręcznie (np. przed startem zasobu) albo podejrzeć, co dokładnie powstanie.
--
--  Przedrostek tabel = Config.Db.prefix (domyślnie `crp_jobcore_bossmenu_`).
--  Tabele licencji NIE są nasze – panel czyta i zapisuje ESX-owe `licenses` / `user_licenses`.
-- ─────────────────────────────────────────────────────────────────────────────

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_members` (
    identifier VARCHAR(60) NOT NULL,
    job VARCHAR(50) NOT NULL,
    hired_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    badge INT NULL,
    seconds INT NOT NULL DEFAULT 0,
    last_duty DATETIME NULL,
    note MEDIUMTEXT NULL,
    note_by VARCHAR(100) NULL,
    note_at DATETIME NULL,
    PRIMARY KEY (identifier, job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_records` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(60) NOT NULL,
    job VARCHAR(50) NOT NULL,
    kind VARCHAR(12) NOT NULL,
    reason VARCHAR(500) NOT NULL,
    by_name VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    void_by VARCHAR(100) NULL,
    void_at DATETIME NULL,
    void_reason VARCHAR(500) NULL,
    INDEX idx_emp (job, identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_promotions` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    identifier VARCHAR(60) NOT NULL,
    job VARCHAR(50) NOT NULL,
    from_grade INT NOT NULL,
    to_grade INT NOT NULL,
    by_name VARCHAR(100) NOT NULL,
    reason VARCHAR(500) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_emp (job, identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_transactions` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    type VARCHAR(3) NOT NULL,
    amount BIGINT NOT NULL,
    by_name VARCHAR(100) NOT NULL,
    label VARCHAR(100) NOT NULL,
    reason VARCHAR(600) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_history` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    by_name VARCHAR(100) NOT NULL,
    entry LONGTEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_settings` (
    job VARCHAR(50) NOT NULL PRIMARY KEY,
    webhooks LONGTEXT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_vehicles` (
    plate VARCHAR(12) NOT NULL PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(60) NULL,
    assigned_identifier VARCHAR(60) NULL,
    assigned_at DATETIME NULL,
    added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_orders` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kind VARCHAR(10) NOT NULL,
    buyer_job VARCHAR(50) NOT NULL,
    supplier_job VARCHAR(50) NOT NULL,
    items LONGTEXT NOT NULL,
    total BIGINT NOT NULL,
    status VARCHAR(12) NOT NULL DEFAULT 'pending',
    delivery VARCHAR(12) NULL,          -- 'physical' = pojazdy dostarczane lawetą (nano skrypt CD)
    note VARCHAR(300) NULL,
    reason VARCHAR(500) NULL,
    by_name VARCHAR(100) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_buyer (buyer_job, id),
    INDEX idx_supplier (supplier_job, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crp_jobcore_bossmenu_products` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    job VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(60) NULL,
    descr VARCHAR(300) NULL,
    price BIGINT NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    access LONGTEXT NULL,
    model VARCHAR(50) NULL,
    express_fee INT NULL,
    INDEX idx_job (job)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── przebieralnia (crp_jobcore_wardrobe) ─────────────────────────────────────
-- Zakładana przez resources/wardrobe/s_wardrobe.lua przy starcie.
CREATE TABLE IF NOT EXISTS `crp_jobcore_wardrobe` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `components` LONGTEXT NULL,
    `props` LONGTEXT NULL,
    `pedmodel` VARCHAR(50) NULL,
    `job` VARCHAR(50) NOT NULL,
    `clothesName` VARCHAR(100) NOT NULL,
    `grades` TEXT NULL,
    `licenses` TEXT NULL,
    INDEX `idx_job` (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
