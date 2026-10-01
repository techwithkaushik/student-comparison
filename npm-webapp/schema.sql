CREATE TABLE IF NOT EXISTS android_metadata (locale TEXT);
CREATE TABLE IF NOT EXISTS psp_students (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 nic_id TEXT NOT NULL UNIQUE,
 sr_no TEXT,
 aadhaar_last4 TEXT,
 student_name TEXT,
 father_name TEXT,
 mother_name TEXT,
 dob TEXT,
 gender TEXT,
 studying_class TEXT,
 mobile TEXT,
 social_category TEXT,
 religion TEXT,
 raw_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS udise_students (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 student_id TEXT NOT NULL,
 pen TEXT NOT NULL UNIQUE,
 uuid_last4 TEXT,
 uuid_status TEXT,
 name_as_uuid TEXT,
 student_name TEXT,
 father_name TEXT,
 mother_name TEXT,
 dob TEXT,
 gender TEXT,
 class_id TEXT,
 class_desc TEXT,
 mobile TEXT,
 social_category TEXT,
 religion TEXT,
 raw_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS student_remarks (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 psp_nic TEXT NOT NULL DEFAULT '',
 udise_pen TEXT NOT NULL DEFAULT '',
 remark TEXT NOT NULL DEFAULT '',
 created_at TEXT NOT NULL,
 updated_at TEXT NOT NULL,
 UNIQUE(psp_nic, udise_pen)
);
CREATE INDEX IF NOT EXISTS idx_psp_class ON psp_students(studying_class);
CREATE INDEX IF NOT EXISTS idx_psp_father ON psp_students(father_name);
CREATE INDEX IF NOT EXISTS idx_psp_mobile ON psp_students(mobile);
CREATE INDEX IF NOT EXISTS idx_psp_mother ON psp_students(mother_name);
CREATE INDEX IF NOT EXISTS idx_psp_name ON psp_students(student_name);
CREATE INDEX IF NOT EXISTS idx_udise_class ON udise_students(class_id, class_desc);
CREATE INDEX IF NOT EXISTS idx_udise_father ON udise_students(father_name);
CREATE INDEX IF NOT EXISTS idx_udise_mobile ON udise_students(mobile);
CREATE INDEX IF NOT EXISTS idx_udise_mother ON udise_students(mother_name);
CREATE INDEX IF NOT EXISTS idx_udise_name ON udise_students(student_name);