-- SmartAttend MySQL schema (MySQL 8.x, InnoDB, utf8mb4)
-- Safe to run more than once (CREATE ... IF NOT EXISTS).

CREATE TABLE IF NOT EXISTS users (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin','teacher') NOT NULL,
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS students (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    student_id      VARCHAR(32)  NOT NULL UNIQUE,
    roll_number     VARCHAR(32),
    name            VARCHAR(120) NOT NULL,
    department      VARCHAR(80),
    year            VARCHAR(16),
    section         VARCHAR(16),
    semester        VARCHAR(16),
    email           VARCHAR(120),
    previous_gpa    DOUBLE NULL,
    face_registered TINYINT(1) NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_students_section (section)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS subjects (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    subject_code VARCHAR(32)  NOT NULL UNIQUE,
    subject_name VARCHAR(120) NOT NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attendance (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    student_id  VARCHAR(32) NOT NULL,
    subject_id  INT NOT NULL,
    date        DATE NOT NULL,
    time        TIME NOT NULL,
    status      VARCHAR(16) NOT NULL DEFAULT 'Present',
    UNIQUE KEY uq_attendance (student_id, subject_id, date),
    INDEX idx_attendance_date (date),
    INDEX idx_attendance_subject (subject_id),
    CONSTRAINT fk_att_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_att_subject FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS face_embeddings (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    student_id   VARCHAR(32) NOT NULL,
    sample_count INT NOT NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_face_student (student_id),
    CONSTRAINT fk_face_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- exam_name uses the default case-insensitive collation, so "Midterm" and
-- "midterm" are the same exam (matches the old SQLite NOCASE behaviour).
CREATE TABLE IF NOT EXISTS marks (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    student_id     VARCHAR(32)  NOT NULL,
    subject_id     INT NOT NULL,
    exam_name      VARCHAR(100) NOT NULL,
    total_marks    DOUBLE NOT NULL,
    obtained_marks DOUBLE NOT NULL,
    percentage     DOUBLE NOT NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_marks (student_id, subject_id, exam_name),
    INDEX idx_marks_subject (subject_id),
    CONSTRAINT fk_marks_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
    CONSTRAINT fk_marks_subject FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS predictions (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    student_id           VARCHAR(32) NOT NULL,
    predicted_score      DOUBLE NOT NULL,
    performance_category VARCHAR(32) NOT NULL,
    risk_level           VARCHAR(16) NOT NULL,
    model_version        VARCHAR(64) NOT NULL,
    created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_predictions_student (student_id),
    CONSTRAINT fk_pred_student FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS audit_log (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    username   VARCHAR(64),
    role       VARCHAR(16),
    ip         VARCHAR(64),
    action     VARCHAR(100) NOT NULL,
    entity     VARCHAR(64),
    entity_id  VARCHAR(64),
    details    TEXT,
    INDEX idx_audit_created (created_at),
    INDEX idx_audit_action (action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS login_attempts (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    username     VARCHAR(64) NOT NULL,
    ip           VARCHAR(64),
    success      TINYINT(1) NOT NULL,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_login_attempts_user (username, attempted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS jobs (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(100) NOT NULL,
    status       VARCHAR(16) NOT NULL,
    progress     INT NOT NULL DEFAULT 0,
    message      VARCHAR(255),
    result_json  LONGTEXT,
    error        TEXT,
    submitted_by VARCHAR(64),
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    started_at   DATETIME NULL,
    finished_at  DATETIME NULL,
    INDEX idx_jobs_name_status (name, status),
    CONSTRAINT chk_job_status CHECK (status IN ('queued','running','succeeded','failed'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS app_meta (
    `key`  VARCHAR(64) PRIMARY KEY,
    value  TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE OR REPLACE VIEW latest_predictions AS
SELECT p.* FROM predictions p
WHERE p.id = (SELECT MAX(p2.id) FROM predictions p2 WHERE p2.student_id = p.student_id);
