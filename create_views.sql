-------------------------------------------------------------------------------
-- Views

CREATE OR REPLACE VIEW queens.course_seasons_offered AS
SELECT
    course_id,
    array_agg(DISTINCT season) AS seasons
FROM
    queens.sections
WHERE
-- TODO make this date math fancier
    year >= (extract(year from now()) - 1)
GROUP BY
    course_id
;

CREATE OR REPLACE VIEW queens.section_class_instructors_name_arr AS
SELECT
    sci.section_class_id,
    array_agg(i.name) AS instructors
FROM
    queens.section_class_instructors sci
        JOIN queens.instructors i ON (instructor_id = id)
GROUP BY
    sci.section_class_id
;
