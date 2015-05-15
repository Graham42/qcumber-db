BEGIN TRANSACTION;

CREATE SCHEMA queens;

CREATE TYPE season as ENUM ('winter', 'spring', 'summer', 'fall');
-- ISO ordering 1..7  TODO check if can easily cast to/from int
CREATE TYPE week_day as ENUM ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY');

CREATE TABLE queens.instructors (
    id      serial PRIMARY KEY,
    name    varchar NOT NULL,
    email   varchar
);

CREATE TABLE queens.subjects (
    id              serial PRIMARY KEY,
    abbreviation    varchar NOT NULL,
    title           varchar
);
CREATE UNIQUE INDEX uk_qsubjects_a ON queens.subjects(abbreviation);

CREATE TABLE queens.courses (
    id                  serial PRIMARY KEY,
    subject_id          integer REFERENCES queens.subjects(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    number              varchar NOT NULL,
    title               varchar,
    description         text,
    career              varchar,
    grading_basis       varchar,
    units               numeric(2),
    -- TODO this should be parsed and the data put in the relevant tables
    enrollment_req      text,
    add_consent         varchar,
    drop_consent        varchar
);
CREATE UNIQUE INDEX uk_qcourses_a ON queens.courses(subject_id, number);

CREATE TABLE queens.course_prereqs (
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    prereq_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, prereq_id)
);
CREATE TABLE queens.course_coreqs (
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    prereq_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, prereq_id)
);
CREATE TABLE queens.course_recommended_prereqs (
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    prereq_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, prereq_id)
);
CREATE TABLE queens.course_exclusions (
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    excluded_id integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE RESTRICT,
    PRIMARY KEY (course_id, excluded_id)
);

CREATE TABLE queens.course_typically_offered (
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    term        season NOT NULL,
    PRIMARY KEY (course_id, term)
);

-- Canadian Engineering Accreditation Board
CREATE TABLE queens.ceab_credits (
    course_id               integer PRIMARY KEY REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    mathematics             integer DEFAULT 0,
    basic_science           integer DEFAULT 0,
    complementary_studies   integer DEFAULT 0,
    engineering_science     integer DEFAULT 0,
    engineering_design      integer DEFAULT 0
);

CREATE TABLE queens.course_components (
    course_id   integer PRIMARY KEY REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    -- laboratory, lecture...
    type        varchar NOT NULL,
    required    boolean NOT NULL
);

CREATE TABLE queens.sections (
    id              bigserial PRIMARY KEY,
    solus_id        integer UNIQUE,
    course_id       integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    type            varchar,
    class_num       varchar,
    year            integer,
    season          season,
    session         varchar,
    campus          varchar,
    campus_location varchar,
    UNIQUE (course_id, class_num)
);

CREATE TABLE queens.section_availability (
    section_id          bigint PRIMARY KEY REFERENCES queens.sections(id) ON UPDATE CASCADE ON DELETE CASCADE,
    status              varchar,
    class_current       integer,
    class_max           integer,
    waitlist_current    integer,
    waitlist_max        integer
);

CREATE TABLE queens.section_classes (
    id              bigserial PRIMARY KEY,
    section_id      bigint REFERENCES queens.sections(id) ON UPDATE CASCADE ON DELETE CASCADE,
    day_of_week     week_day,
    start_time      time,
    end_time        time,
    term_start      date,
    term_end        date,
    location        varchar
);

CREATE TABLE queens.section_class_instructors (
    section_class_id    bigint REFERENCES queens.section_classes(id) ON UPDATE CASCADE ON DELETE CASCADE,
    instructor_id       integer REFERENCES queens.instructors(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE queens.textbooks (
    id              serial PRIMARY KEY,
    isbn_10         char(10),
    isbn_13         char(13),
    title           text,
    authors         text[]
);

CREATE TABLE queens.textbooks_bookstore (
    textbook_id     integer PRIMARY KEY REFERENCES queens.textbooks(id) ON UPDATE CASCADE ON DELETE CASCADE,
    url             varchar,
    price           numeric(2),
    available_new   integer
);

CREATE TABLE queens.course_textbooks (
    textbook_id integer REFERENCES queens.textbooks(id) ON UPDATE CASCADE ON DELETE CASCADE,
    course_id   integer REFERENCES queens.courses(id) ON UPDATE CASCADE ON DELETE CASCADE,
    required    boolean,
    PRIMARY KEY (textbook_id, course_id)
);

COMMIT;
