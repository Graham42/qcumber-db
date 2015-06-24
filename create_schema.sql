BEGIN TRANSACTION;

DROP SCHEMA IF EXISTS queens CASCADE;
CREATE SCHEMA queens;

-- In the future may want to separate type creation from the queens schema
DROP TYPE IF EXISTS season;
CREATE TYPE season as ENUM ('winter', 'spring', 'summer', 'fall');

DROP TABLE IF EXISTS public.iso_week_day;
DROP TYPE IF EXISTS week_day;
-- enums make the data more meaningful to look at instead of having to remember that 1 is Monday etc
CREATE TYPE week_day as ENUM ('MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY');
CREATE TABLE public.iso_week_day (
    iso_dow     integer,
    week_day    week_day,
    PRIMARY KEY (iso_dow, week_day)
);
INSERT INTO public.iso_week_day VALUES
(1, 'MONDAY'),
(2, 'TUESDAY'),
(3, 'WEDNESDAY'),
(4, 'THURSDAY'),
(5, 'FRIDAY'),
(6, 'SATURDAY'),
(7, 'SUNDAY');


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

CREATE TABLE queens.instructors (
    id      serial PRIMARY KEY,
    name    varchar NOT NULL,
    email   varchar
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
-- on delete, trigger copy textbook to historical, TODO check if ON DELETE needs to restrict to get the data from other tables


-- Historical data ideas
-- course instructors - who, when
-- text books - title, when
-- when a course was last offered
-- when data was last loaded, be able to show more relevance for courses no longer available

-- Views
-- what courses instructors are currently teaching
-- what courses instructors have taught in the past
COMMIT;
