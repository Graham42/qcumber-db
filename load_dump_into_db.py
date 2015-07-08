#!/usr/bin/env python
# please pardon the hackiness of this script

from os import path, listdir
from sys import exit
from functools import reduce
import re
import yaml
import psycopg2

DATA_DIR = "qcumber-data/data"

if not path.exists(DATA_DIR):
    print("Directory '{0}' not found".format(DATA_DIR))
    exit(1)

def yaml_data_files(subdir):
    fulldir = path.join(DATA_DIR, subdir)
    files = [ path.join(fulldir, f) for f in listdir(fulldir)
                if path.isfile(path.join(fulldir, f)) and path.splitext(f)[-1] == '.yaml' ]
    if len(files) == 0:
        print("WARNING: no yaml files found in {0}".format(fulldir))
    return files

def pop_fields(o, fields):
    """
    Populate a new object as a subset of an existing obj given an array of
    fields. The fields in the old object are deleted.
    """
    new_o = {}
    for key, newkey in fields.items():
        newkey = re.sub(r'__.*', "", newkey)
        if key.find('.') != -1:
            nested_keys = key.split('.')
            nested = reduce(dict.get, nested_keys[:-1], o)
            new_o[newkey] = nested.pop(nested_keys[-1], None)
        else:
            new_o[newkey] = o.pop(key, None)
    return new_o

# define mapping of yaml fields to sql table fields
fields = {
    'subjects': {
        'abbreviation': 'abbreviation',
        'title': 'title',
    },
    'courses': {
        'basic.subject': 'subject_abbr__REF__subject_id',
        'basic.number': 'number',
        'basic.title': 'title',
        'basic.description': 'description',
        'extra.career': 'career',
        'extra.grading_basis': 'grading_basis',
        'extra.units': 'units',
        'extra.enrollment_requirement': 'enrollment_req',
        'extra.add_consent': 'add_consent',
        'extra.drop_consent': 'drop_consent',
    },
    'course_typically_offered': {
        'extra.typically_offered': 'UNUSED',
    },
    'ceab_credits': {
        'extra.CEAB.Basic Sci': 'basic_science',
        'extra.CEAB.Comp St': 'complementary_studies',
        'extra.CEAB.Eng Des': 'engineering_design',
        'extra.CEAB.Eng Sci': 'engineering_science',
        'extra.CEAB.Math': 'mathematics',
    },
    'course_components': {}, # array so special case
# TODO fix switched properties
    'sections': {
        'basic.solus_id': 'class_num', #'solus_id',
        'basic.course': 'course_num__REF__course_id',
        'basic.subject': 'subject_abbr__NOCOLUMN',
        'basic.type': 'type',
        'basic.class_num': 'solus_id', #'class_num',
        'basic.year': 'year',
        'basic.season': 'season',
        'details.session': 'session',
        'details.campus': 'campus',
        'details.location': 'campus_location',
    },
    'section_availability': {
        'basic.status': 'status',
        'availability.class_curr': 'class_current',
        'availability.class_max': 'class_max',
        'availability.wait_curr': 'waitlist_current',
        'availability.wait_max': 'waitlist_max',
    },
    'section_classes': { #loop through classes array
        'day_of_week': 'day_of_week',
        'start_time': 'start_time',
        'end_time': 'end_time',
        'term_start': 'term_start',
        'term_end': 'term_end',
        'location': 'location',
    },
    'instructors': {}, #special case
    'section_class_instructors': {}, #special case
    'textbooks': {},
    'textbooks_bookstore': {},
    'course_textbooks': {},
}

unused_data = {'subjects': [], 'courses': [], 'sections': [], 'textbooks': []}
ids = {'subjects': {}, 'courses': {}, 'sections': {}, 'textbooks': {}, 'instructors': {}}


conn = psycopg2.connect(dbname="qcumberdb", host="localhost", user="postgres", password="Default1$")
conn.set_session(autocommit=True)
cur = conn.cursor()

cur.execute("SELECT * FROM public.iso_week_day")
ISO_WEEK_DAYS = {d[0]: d[1] for d in cur.fetchall()}
if len(ISO_WEEK_DAYS.keys()) != 7:
    print("Missing day of week data")
    exit(1)

for s in yaml_data_files('subjects'):
    with open(s, 'r') as f:
        contents = f.read()
        obj = yaml.load(contents)
        subject = pop_fields(obj, fields['subjects'])
        obj.pop('_unique', None)
        # someday in postgres 9.5+ use UPSERT
        try:
            cur.execute("""
                INSERT INTO queens.subjects (abbreviation, title)
                VALUES (%(abbreviation)s, %(title)s);""", subject)
        except psycopg2.IntegrityError as e:
            if e.pgerror.find('uk_qsubjects_id') == -1:
                raise e
            cur.execute("""
                UPDATE queens.subjects
                SET title = %(title)s
                WHERE abbreviation = %(abbreviation)s;""", subject)
        if len(obj.keys()) > 1:
            unused_data['subjects'].append(obj)
# put subject ids in a hash for quick reference by abbreviation
cur.execute("SELECT id, abbreviation FROM queens.subjects")
ids['subjects'] = {s[1]: s[0] for s in cur.fetchall()}
print("Finished subjects...")

columns = {}
for thing in fields:
    columns[thing] = sorted([re.sub(r'.*__REF__', "", col) for col in fields[thing].values() if col.find("__NOCOLUMN") == -1])
columns['section_availability'].append('section_id')
columns['section_classes'].append('section_id')

queries = {
    'insert_course': """
        INSERT INTO queens.courses ({0})
        VALUES ({1});
        """.format(
            ", ".join(columns['courses']),
            ", ".join(["%({0})s".format(x) for x in columns['courses']])
        ),
    'update_course': """
        UPDATE queens.courses
        SET {0}
        WHERE subject_id = %(subject_id)s AND number = %(number)s
        """.format(
            ", ".join(["{0} = %({0})s".format(x) for x in columns['courses']])
        ),

    'insert_ceab': """
        INSERT INTO queens.ceab_credits ({0})
        VALUES ({1});
        """.format(
            ", ".join(columns['ceab_credits']),
            ", ".join(["%({0})s".format(x) for x in columns['ceab_credits']])
        ),
    'update_ceab': """
        UPDATE queens.ceab_credits
        SET {0}
        WHERE course_id = %(course_id)s
        """.format(
            ", ".join(["{0} = %({0})s".format(x) for x in columns['ceab_credits']])
        ),

    'insert_section': """
        INSERT INTO queens.sections({0})
        VALUES ({1});
        """.format(
            ", ".join(columns['sections']),
            ", ".join(["%({0})s".format(x) for x in columns['sections'] if x.find('__NOCOLUMN') == -1])
        ),
    'update_section': """
        UPDATE queens.sections
        SET {0}
        WHERE
            course_id = %(course_id)s
            AND class_num = %(class_num)s
        """.format(
            ", ".join(["{0} = %({0})s".format(x) for x in columns['sections'] if x.find('__NOCOLUMN') == -1])
        ),

    'insert_availability': """
        INSERT INTO queens.section_availability({0})
        VALUES ({1});
        """.format(
            ", ".join(columns['section_availability']),
            ", ".join(["%({0})s".format(x) for x in columns['section_availability']])
        ),
    'update_availability': """
        UPDATE queens.section_availability
        SET {0}
        WHERE section_id = %(section_id)s
        """.format(
            ", ".join(["{0} = %({0})s".format(x) for x in columns['section_availability']])
        ),

    'insert_class': """
        INSERT INTO queens.section_classes({0})
        VALUES ({1})
        RETURNING id;
        """.format(
            ", ".join(columns['section_classes']),
            ", ".join(["%({0})s".format(x) for x in columns['section_classes']])
        ),
}

for c in yaml_data_files('courses'):
    #break
    with open(c, 'r') as f:
        contents = f.read()
        obj = yaml.load(contents)

        obj.pop('_unique', None)
        course = pop_fields(obj, fields['courses'])
        # get subject id by abbrev
        course['subject_id'] = ids['subjects'][course['subject_abbr']]
        # write course
        try:
            try:
                cur.execute(queries['insert_course'], course)
            except psycopg2.IntegrityError as e:
                if e.pgerror.find('uk_qcourses_id') == -1:
                    raise e
                cur.execute(queries['update_course'], course)
        except psycopg2.DataError as e:
            print(course)
            raise e

        # after insert, get course id to be able to write other course related tables
        cur.execute("""SELECT id FROM queens.courses
            WHERE subject_id = %(subject_id)s AND number = %(number)s""", course)
        course_id = cur.fetchone()[0]
        ids['courses']["{0} {1}".format(course['subject_abbr'],course['number'])] = course_id

        # This data is unused, it's derived from what's actually offered instead
        pop_fields(obj, fields['course_typically_offered'])

        # components are things like Lecture, Tutorial, Lab
        cur.execute("""
            DELETE FROM queens.course_components
            WHERE course_id = %(course_id)s;
            """, {'course_id': course_id})
        components = obj['extra'].pop('course_components', {})
        for key, value in components.items():
            # not sure the possible values for this, right now the db has it as a boolean
            # but may not be binary
            if value not in ["Required"]:
                print("Unknown value for course component: {0} : {1}".format(key, value))
                exit(1)
            cur.execute("""
                INSERT INTO queens.course_components (course_id, type, required)
                VALUES (%s, %s, %s);""", (course_id, key, value == "Required" ))

        # Engineering accreditation related credits
        ceab = pop_fields(obj, fields['ceab_credits'])
        ceab['course_id'] = course_id
        try:
            cur.execute(queries['insert_ceab'], ceab)
        except psycopg2.IntegrityError:
            cur.execute(queries['update_ceab'], ceab)

        if len(obj.keys()) > 1:
            unused_data['courses'].append(obj)
print("Finished courses...")

cur.execute("SELECT abbreviation, number, c.id FROM queens.subjects s JOIN queens.courses c ON (s.id = c.subject_id)")
ids['courses'] = {"{0} {1}".format(m[0], m[1]): m[2] for m in cur.fetchall()}

for s in yaml_data_files('sections'):
    with open(s, 'r') as f:
        contents = f.read()
        obj = yaml.load(contents)

        obj.pop('_unique', None)
        section = pop_fields(obj, fields['sections'])
        # get course id by subject abbrev and course num
        course_str = "{0} {1}".format(section['subject_abbr'],section['course_num'])
        section['course_id'] = ids['courses'][course_str]
        # write / update the section
        cur.execute("""
            UPDATE queens.sections SET solus_id = null
            WHERE solus_id = %(solus_id)s""", section)
        try:
            cur.execute(queries['insert_section'], section)
        except psycopg2.IntegrityError as e:
            if e.pgerror.find('uk_qsections_id') == -1:
                raise e
            cur.execute(queries['update_section'], section)

        # get the section id for referential tables
        cur.execute("""SELECT id FROM queens.sections
            WHERE course_id = %(course_id)s AND class_num = %(class_num)s""", section)
        try:
            section_id = cur.fetchone()[0]
        except Exception as e:
            print(section)
            raise e

        # section availability
        available = pop_fields(obj, fields['section_availability'])
        available['section_id'] = section_id
        try:
            cur.execute(queries['insert_availability'], available)
        except psycopg2.IntegrityError:
            cur.execute(queries['update_availability'], available)

        cur.execute("""
            DELETE FROM queens.section_classes
            WHERE section_id = %s
            """, (section_id,))
        for cl in obj['classes']:
            clz = pop_fields(cl, fields['section_classes'])
            clz['section_id'] = section_id
            if clz['day_of_week'] is not None:
                clz['day_of_week'] = ISO_WEEK_DAYS[clz['day_of_week']]
            try:
                cur.execute(queries['insert_class'], clz)
            except psycopg2.IntegrityError as e:
                print(section)
                print(clz)
                raise e
            clz_id = cur.fetchone()[0]

            cur.execute("""
                DELETE FROM queens.section_class_instructors
                WHERE section_class_id = %s
                """, (clz_id,))
            for name in cl.pop('instructors', []):
                # add the instructor if not there yet
                if name not in ids['instructors']:
                    try:
                        cur.execute("INSERT INTO queens.instructors (name) VALUES (%s)", (name,))
                    except psycopg2.IntegrityError:
                        pass
                    cur.execute("SELECT id FROM queens.instructors where name = %s", (name,))
                    ids['instructors'][name] = cur.fetchone()[0]
                # add reference from class to instructor
                cur.execute("""
                    INSERT INTO queens.section_class_instructors VALUES (%s, %s)
                    """, (clz_id, ids['instructors'][name]))

        obj['classes'] = [x for x in obj['classes'] if x != {}]
        if len(obj['classes']) == 0:
            obj.pop('classes', None)

        if len(obj.keys()) > 1:
            unused_data['sections'].append(obj)
print("Finished sections...")


#TODO textbooks data


# sanity check to see if we missed any data
def report_unused(obj):
    try:
        obj.keys()
    except:
        return obj
    if len(obj.keys()) == 0:
        return None
    else:
        obj = {key: report_unused(obj[key]) for key in obj.keys()}
        obj = {key: obj[key] for key in obj.keys() if obj[key] is not None}
        if len(obj.keys()) == 0:
            return None
        else:
            return obj

for category in unused_data.keys():
    unused_data[category] = [report_unused(x) for x in unused_data[category]]
    unused_data[category] = [x for x in unused_data[category] if x is not None]
print(report_unused(unused_data))


cur.close()
conn.close()

print("All done!")
