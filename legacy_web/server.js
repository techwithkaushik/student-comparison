const express = require('express');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const initSqlJs = require('sql.js');

const app = express();
const PORT = Number(process.env.PORT || 3000);
const ROOT = __dirname;
const DB_FILE = path.join(ROOT, 'student_compare.sqlite');
const SCHEMA_FILE = path.join(ROOT, 'db', 'schema.sql');
const UPLOAD_DIR = path.join(ROOT, 'uploads');
fs.mkdirSync(UPLOAD_DIR, {
    recursive: true
});
const upload = multer({
    dest: UPLOAD_DIR,
    limits: {
        fileSize: 100 * 1024 * 1024
    },
    fileFilter: (_r, f, cb) => cb(null, /json/i.test(f.mimetype) || /\.json$/i.test(f.originalname))
});
app.use(express.json({
    limit: '10mb'
}));
app.use(express.static(path.join(ROOT, 'public')));

const PSP_FIELDS = ["S.No.", "Session", "Student NIC ID", "SR No.", "Aadhar Number", "Student Name", "Father Name", "Mother Name", "DOB", "Gender", "Social Category", "Religion", "Mother Tongue", "Rural/Urban", "Date of Admission", "Admission Number/SR No", "Belong To BPL", "Belong to Disadvantaged Group", "Getting Free Education", "Studying in Class", "Class Studied in Prev. Year", "If in Class 1, Status of Previous Year", "Days child attended school (in the prev. year)", "Medium of Instruction", "Type of Disablity", "Facilities received by CWSN", "No. Of Uniform Sets", "Free Text Books", "Free Transport", "Free Escort", "MDM Beneficiary", "Free Hostel Facility", "Child attended Special Training", "In Last Examination Appeard", "In Last Examination Passed", "Stream (Grades 11 & 12)", "Trade/Sector (Grades 9 to 12)", "Iron & Folic Acid Tablets", "Deworming Tablets", "Vitamin-A Supplement", "Mobile Number", "Habitation or Locality", "In Last Examination % Marks", "Email Address"];
const UDISE_FIELDS = ["studentId", "studentCodeNat", "studentCodeState", "schoolId", "studentName", "gender", "genderDesc", "socCatId", "socialCategoryList", "socialCategoryDesc", "minorityId", "minorityDesc", "uuid", "uuidMasked", "isUuidAvailable", "isValidUuid", "nameAsUuid", "uuidStatus", "uuidStatusDesc", "uuidValidateRemarks", "uuidValidateDate", "dob", "guardianName", "fatherName", "motherName", "address", "pincode", "primaryMobile", "secondaryMobile", "isBplYN", "aayBplYN", "ewsYN", "cwsnYN", "natIndYN", "natOtherCountry", "motherTongue", "motherTongueDesc", "email", "acYearId", "lastYearId", "lastYearIdDesc", "classId", "classDesc", "classPyId", "classPyDesc", "sectionDesc", "sectionPyDesc", "sectionId", "impairmentType", "disabilityCerti", "impairmentPercent", "ooscYN", "ooscMainstreamedYN", "profileStatus", "formStatus", "ageCheckSkipped", "academicStreamDesc", "admnNumber", "isRepeater", "inactiveDate", "statusId", "statusDesc", "statusL1Id", "statusL1Desc", "statusL2Id", "statusL2Desc", "isNew", "bloodGroup", "bloodGroupDesc", "deleteReason", "deleteReasonDesc", "schUdiseCode", "schoolName", "yearId", "studentMovType", "lastModifiedOn", "lastModifiedBy", "apaarIdStatus", "apaarId", "apaarIdStatusDesc", "schoolPY", "mbuStatusDesc", "examFormStatus", "nameChangeCountTotal", "nameChangeCountAdmin", "nameChangeCountSchool"];
const qid = s => '"' + String(s).replace(/"/g, '""') + '"';
const clean = v => String(v ?? '').trim();
const norm = v => clean(v).toUpperCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, '').replace(/\s+/g, ' ').trim();
const digits = v => clean(v).replace(/\D/g, '');
const last4 = v => {
    const x = digits(v);
    return x.length >= 4 ? x.slice(-4) : '';
};

function normalizeDob(v) {
    const x = clean(v).replace(/[.-]/g, '/');
    const m = x.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
    return m ? `${m[1].padStart(2,'0')}/${m[2].padStart(2,'0')}/${m[3]}` : x;
}

function classNum(v) {
    const x = norm(v).replace(/^(CLASS|GRADE)\s*/, '').replace(/\./g, '').trim();
    const map = {
        PREPRIMARY: 0,
        NURSERY: 0,
        KG: 0,
        LKG: 0,
        UKG: 0,
        FIRST: 1,
        SECOND: 2,
        THIRD: 3,
        FOURTH: 4,
        FIFTH: 5,
        SIXTH: 6,
        SEVENTH: 7,
        EIGHT: 8,
        EIGHTH: 8,
        NINTH: 9,
        TENTH: 10,
        ELEVENTH: 11,
        TWELFTH: 12,
        I: 1,
        II: 2,
        III: 3,
        IV: 4,
        V: 5,
        VI: 6,
        VII: 7,
        VIII: 8,
        IX: 9,
        X: 10,
        XI: 11,
        XII: 12
    };
    if (/^\d+(?:\.0+)?$/.test(x)) return Number(x);
    if (map[x] !== undefined) return map[x];
    const m = x.match(/^(\d{1,2})(?:ST|ND|RD|TH)?$/);
    return m ? Number(m[1]) : null;
}
const classCanon = v => {
    const n = classNum(v);
    return n === null ? norm(v) : String(n)
};

function genderNorm(v) {
    const x = norm(v);
    return ['1', 'MALE', 'M'].includes(x) ? 'MALE' : ['2', 'FEMALE', 'F'].includes(x) ? 'FEMALE' : x;
}

function socialCatNorm(v) {
    const x = norm(v);
    if (x.includes('GENERAL') || x === '1') return 'GENERAL';
    if (x.includes('OBC') || x === '4') return 'OBC';
    if (x.includes('SC') || x === '2') return 'SC';
    if (x.includes('ST') || x === '3') return 'ST';
    if (x.includes('SBC') || x === '5') return 'SBC';
    console.log("Category "+x);
    return x;
}

function religionNorm(v) {
    const x = norm(v);
    if (x.includes('MUSLIM') || x === '1') return 'MUSLIM';
    if (x.includes('CHRISTIAN') || x === '2') return 'CHRISTIAN';
    if (x.includes('SIKH') || x === '3') return 'SIKH';
    if (x.includes('BUDDHIST') || x === '4') return 'BUDDHIST';
    if (x.includes('PARSI') || x === '5') return 'PARSI';
    if (x.includes('JAIN') || x === '6') return 'JAIN';
    // UDISE में 7, NA या खाली होने पर उसे HINDU (Non-Minority) माना जाएगा
    if (x.includes('HINDU') || x.includes('NON MINORITY') || x === '7' || x === 'NA' || !x) return 'HINDU';
    console.log("Religion "+x);
    return x;
}

function nameCompatible(a, b, alias = '') {
    const A = norm(a),
        B = norm(b),
        C = norm(alias);
    if (!A || !B) return false;
    const variants = [B, C].filter(Boolean);
    const tokenCompat = (x, y) => {
        if (x === y) return true;
        const xt = x.split(' ').filter(Boolean),
            yt = y.split(' ').filter(Boolean);
        if (xt.length === 0 || yt.length === 0) return false;
        const short = xt.length <= yt.length ? xt : yt,
            long = xt.length <= yt.length ? yt : xt;
        // First-name-only vs first+last-name (e.g. KAPTAN vs KAPTAN SINGH).
        if (short.every(t => long.includes(t))) return true;
        // Allow minor spelling/transliteration variation in a token, but do not
        // treat arbitrary sibling names as compatible.
        if (short.length === 1) return sim(short[0], long[0]) >= 0.75;
        return short.length === long.length && short.every((t, i) => sim(t, long[i]) >= 0.80);
    };
    return variants.some(v => tokenCompat(A, v));
}

function nameEvidence(p, u) {
    // UDISE can contain the name used in the student profile and the name
    // returned by Aadhaar validation. Either can establish name compatibility.
    return nameCompatible(p.student_name, u.student_name, u.name_as_uuid);
}

function pspMap(r) {
    const aad = clean(r['Aadhar Number']);
    return {
        psp_nic_id: clean(r['Student NIC ID']),
        sr_no: clean(r['SR No.']),
        aadhaar_last4: last4(aad),
        student_name: clean(r['Student Name']),
        father_name: clean(r['Father Name']),
        mother_name: clean(r['Mother Name']),
        dob: normalizeDob(r['DOB']),
        gender: clean(r['Gender']),
        studying_class: clean(r['Studying in Class']),
        mobile: clean(r['Mobile Number']),
        social_category: clean(r['Social Category']), // <-- नया फील्ड
        religion: clean(r['Religion']),
        raw: r,
        _nameNorm: norm(r['Student Name']),
        _fatherNorm: norm(r['Father Name']),
        _motherNorm: norm(r['Mother Name']),
        _dobNorm: normalizeDob(r['DOB']),
        _genderNorm: genderNorm(r['Gender']),
        _mobileDigits: digits(r['Mobile Number']),
        _classCanon: classCanon(r['Studying in Class']),
        _categoryNorm: socialCatNorm(r['Social Category']),
        _religionNorm: religionNorm(r['Religion'])
    };
}

function udiseMap(r) {
    const aad = clean(r.uuid);
    const present = !!aad && !/^\*+9999$/.test(aad) && last4(aad) !== '9999';
    return {
        student_id: clean(r.studentId),
        student_code_nat: clean(r.studentCodeNat),
        uuid_last4: present ? last4(aad) : '',
        uuid_status: r.uuidStatus,
        name_as_uuid: clean(r.nameAsUuid),
        student_name: clean(r.studentName),
        father_name: clean(r.fatherName),
        mother_name: clean(r.motherName),
        dob: normalizeDob(r.dob),
        gender: genderNorm(r.gender),
        class_id: clean(r.classId),
        class_desc: clean(r.classDesc),
        mobile: clean(r.primaryMobile),
        social_category: socialCatNorm(r.socialCategoryDesc || r.socCatId), // <-- नया फील्ड
        religion: religionNorm(r.minorityDesc || r.minorityId),
        raw: r,
        _nameNorm: norm(r.studentName),
        _nameUuidNorm: norm(r.nameAsUuid),
        _fatherNorm: norm(r.fatherName),
        _motherNorm: norm(r.motherName),
        _dobNorm: normalizeDob(r.dob),
        _genderNorm: genderNorm(r.gender),
        _mobileDigits: digits(r.primaryMobile),
        _classIdCanon: classCanon(r.classId),
        _classDescCanon: classCanon(r.classDesc),
        _categoryNorm: socialCatNorm(r.socialCategoryDesc || r.socCatId),
        _religionNorm: religionNorm(r.minorityDesc || r.minorityId)
    };
}
let db;
let comparisonCache = null;
function invalidateComparisonCache() { comparisonCache = null; }

function saveDb() {
    const tmp = DB_FILE + '.tmp';
    fs.writeFileSync(tmp, Buffer.from(db.export()));
    fs.renameSync(tmp, DB_FILE);
}

function queryAll(sql, params = []) {
    const st = db.prepare(sql);
    try {
        st.bind(params);
        const a = [];
        while (st.step()) a.push(st.getAsObject());
        return a;
    } finally {
        st.free();
    }
}

function queryOne(sql, params = []) {
    return queryAll(sql, params)[0] || null;
}

function exec(sql, params = []) {
    const st = db.prepare(sql);
    try {
        st.run(params);
    } finally {
        st.free();
    }
}

function tableRows(type) {
    const fields = type === 'psp' ? PSP_FIELDS : UDISE_FIELDS;
    const table = type === 'psp' ? 'psp_student_data' : 'udise_data';
    return queryAll(`SELECT ${fields.map(qid).join(',')} FROM ${qid(table)} ORDER BY ${qid(fields[type==='psp'?2:4])}, _id`).map(r => r);
}

function extractRows(data) {
    if (Array.isArray(data)) return data;
    if (data && Array.isArray(data.data)) return data.data;
    if (data && Array.isArray(data.result)) return data.result;
    if (data && data.result && Array.isArray(data.result.data)) return data.result.data;
    return [];
}

function validateRows(rows, type) {
    const seen = new Set(),
        valid = [],
        invalid = [];
    rows.forEach((r, i) => {
        if (!r || typeof r !== 'object' || Array.isArray(r)) return invalid.push({
            index: i + 1,
            reason: 'Record object नहीं है'
        });
        const key = type === 'psp' ? clean(r['Student NIC ID']) : clean(r.studentId);
        if (!key) return invalid.push({
            index: i + 1,
            reason: type === 'psp' ? 'Student NIC ID missing' : 'studentId missing'
        });
        if (seen.has(key)) return invalid.push({
            index: i + 1,
            reason: `Duplicate ID: ${key}`
        });
        seen.add(key);
        valid.push(r);
    });
    return {
        valid,
        invalid
    };
}

function importRows(type, rows) {
    const fields = type === 'psp' ? PSP_FIELDS : UDISE_FIELDS;
    const table = type === 'psp' ? 'psp_student_data' : 'udise_data';
    
    // Turbocharge SQLite internal performance parameters for batch updates
    db.run('PRAGMA synchronous = OFF;');
    db.run('PRAGMA journal_mode = MEMORY;');
    db.run('PRAGMA cache_size = -20000;'); // Allocate roughly ~20MB of cache storage
    
    db.run('BEGIN TRANSACTION;');
    try {
        db.run(`DELETE FROM ${qid(table)}`);
        
        const cols = fields.map(qid).join(',');
        const ph = fields.map(() => '?').join(',');
        const st = db.prepare(`INSERT INTO ${qid(table)} (${cols}) VALUES (${ph})`);
        
        try {
            for (const r of rows) {
                const values = fields.map(f => {
                    if (Object.prototype.hasOwnProperty.call(r, f)) {
                        return r[f] === null ? null : String(r[f]);
                    }
                    return null;
                });
                st.run(values);
            }
        } finally {
            st.free();
        }
        db.run('COMMIT;');
        saveDb();
    } catch (e) {
        try {
            db.run('ROLLBACK;');
        } catch {}
        throw e;
    } finally {
        // Reset safety parameters back to normal execution defaults
        db.run('PRAGMA synchronous = NORMAL;');
        db.run('PRAGMA journal_mode = WAL;');
    }
}

app.get('/api/health', (_r, res) => res.json({
    ok: true
}));
app.get('/api/stats', (_r, res) => {
    try {
        res.json({
            psp: Number(queryOne('SELECT COUNT(*) n FROM psp_student_data').n || 0),
            udise: Number(queryOne('SELECT COUNT(*) n FROM udise_data').n || 0)
        })
    } catch (e) {
        res.status(500).json({
            error: e.message
        })
    }
});
app.post('/api/import/:type', upload.single('file'), (req, res) => {
    const type = req.params.type;
    if (!['psp', 'udise'].includes(type)) return res.status(400).json({
        error: 'Invalid import type'
    });
    try {
        if (!req.file) return res.status(400).json({
            error: 'JSON file required'
        });
        let data;
        try {
            data = JSON.parse(fs.readFileSync(req.file.path, 'utf8').replace(/^\uFEFF/, ''));
        } catch (e) {
            return res.status(400).json({
                error: `Invalid JSON: ${e.message}`
            })
        }
        const rows = extractRows(data);
        if (!rows.length) return res.status(400).json({
            error: 'No student records found'
        });
        const v = validateRows(rows, type);
        if (!v.valid.length) return res.status(400).json({
            error: 'Valid student records नहीं मिले',
            invalid: v.invalid.slice(0, 20)
        });
        importRows(type, v.valid);
        invalidateComparisonCache();
        res.json({
            ok: true,
            type,
            count: v.valid.length,
            total: rows.length,
            invalid: v.invalid.length,
            storedFields: (type === 'psp' ? PSP_FIELDS : UDISE_FIELDS).length,
            invalidSamples: v.invalid.slice(0, 20)
        });
    } catch (e) {
        res.status(500).json({
            error: e.message
        })
    } finally {
        if (req.file) fs.unlink(req.file.path, () => {})
    }
});

function aadhaarState(p, u) {
    const pa = !!p.aadhaar_last4,
        ua = !!u.uuid_last4;
    if (!pa && !ua) return 'NOT_FOUND';
    if (pa !== ua) return 'MISMATCH';
    return p.aadhaar_last4 === u.uuid_last4 ? 'MATCH' : 'MISMATCH';
}

function compare(p, u) {
    const d = [];
    const aadhaar = aadhaarState(p, u);

    // Aadhaar/mobile are REVIEW FLAGS, not identity-breaking mismatches.
    if (aadhaar === 'MISMATCH') d.push('AADHAAR_MISMATCH');
    if (aadhaar === 'NOT_FOUND') d.push('AADHAAR_NOT_FOUND');

    if (norm(p.student_name) !== norm(u.student_name)) d.push('NAME_MISMATCH');
    if (normalizeDob(p.dob) !== normalizeDob(u.dob)) d.push('DOB_MISMATCH');
    if (p.father_name && u.father_name && norm(p.father_name) !== norm(u.father_name)) d.push('FATHER_MISMATCH');
    if (p.mother_name && u.mother_name && norm(p.mother_name) !== norm(u.mother_name)) d.push('MOTHER_MISMATCH');
    if (classCanon(p.studying_class) !== classCanon(u.class_id) && classCanon(p.studying_class) !== classCanon(u.class_desc)) d.push('CLASS_MISMATCH');
    if (p.gender && u.gender && genderNorm(p.gender) !== genderNorm(u.gender)) d.push('GENDER_MISMATCH');

    const pm = digits(p.mobile);
    const um = digits(u.mobile);
    if (!pm || !um) d.push('MOBILE_NOT_FOUND');
    else if (pm !== um) d.push('MOBILE_MISMATCH');

    if (socialCatNorm(p.social_category) !== socialCatNorm(u.social_category)) d.push('CATEGORY_MISMATCH');
    if (religionNorm(p.religion) !== religionNorm(u.religion)) d.push('RELIGION_MISMATCH');
    return d;
}

function hasCoreIdentityMismatch(diffs) {
    // A student remains MATCHED when only Aadhaar/mobile are missing or different.
    // These two fields are deliberately excluded from the identity decision.
    return diffs.some(d => !['AADHAAR_MISMATCH', 'AADHAAR_NOT_FOUND', 'MOBILE_MISMATCH', 'MOBILE_NOT_FOUND'].includes(d));
}

function score(p, u) {
    const w = {
            aad_score: 5,
            name_score: 20,
            dob_score: 20,
            father_score: 15,
            mother_score: 10,
            class_score: 10,
            gender_score: 5,
            mobile_score: 5,
            category_score: 5,
            religion_score: 5
        },
        a = aadhaarState(p, u);
    let e = 0,
        t = 0;
    t += w.aad_score;
    if (a === 'MATCH') e += w.aad_score;
    if (p.student_name || u.student_name) {
        t += w.name_score;
        if (norm(p.student_name) === norm(u.student_name)) e += w.name_score
    }
    if (p.dob || u.dob) {
        t += w.dob_score;
        if (normalizeDob(p.dob) === normalizeDob(u.dob)) e += w.dob_score
    }
    if (p.father_name && u.father_name) {
        t += w.father_score;
        if (norm(p.father_name) === norm(u.father_name)) e += w.father_score
    }
    if (p.mother_name && u.mother_name) {
        t += w.mother_score;
        if (norm(p.mother_name) === norm(u.mother_name)) e += w.mother_score
    }
    if (p.studying_class || u.class_id || u.class_desc) {
        t += w.class_score;
        if (classCanon(p.studying_class) === classCanon(u.class_id) || classCanon(p.studying_class) === classCanon(u.class_desc)) e += w.class_score
    }
    if (p.gender || u.gender) {
        t += w.gender_score;
        if (genderNorm(p.gender) === genderNorm(u.gender)) e += w.gender_score
    }
    if (p.mobile && u.mobile) {
        t += w.mobile_score;
        if (digits(p.mobile) === digits(u.mobile)) e += w.mobile_score
    }
    // सोशल कैटेगरी और रिलिजन का स्कोर इवैल्यूएशन (नये)
    if (p.social_category || u.social_category) {
        t += w.category_score;
        if (socialCatNorm(p.social_category) === socialCatNorm(u.social_category)) e += w.category_score;
    }
    if (p.religion || u.religion) {
        t += w.religion_score;
        if (religionNorm(p.religion) === religionNorm(u.religion)) e += w.religion_score;
    }
    return t ? Math.round(e / t * 100) : 0;
}

function candScore(p, u) {
    const ns = Math.max(sim(p.student_name, u.student_name), sim(p.student_name, u.name_as_uuid));
    let s = Math.round(ns * 20) + Math.round(sim(p.father_name, u.father_name) * 15) + Math.round(sim(p.mother_name, u.mother_name) * 10);
    if (p.dob && u.dob && normalizeDob(p.dob) === normalizeDob(u.dob)) s += 20;
    if (classCanon(p.studying_class) === classCanon(u.class_id) || classCanon(p.studying_class) === classCanon(u.class_desc)) s += 10;
    if (genderNorm(p.gender) === genderNorm(u.gender) && genderNorm(p.gender)) s += 5;
    if (aadhaarState(p, u) === 'MATCH') s += 5;
    if (digits(p.mobile) && digits(p.mobile) === digits(u.mobile)) s += 5;
    if (socialCatNorm(p.social_category) === socialCatNorm(u.social_category)) s += 5;
    if (religionNorm(p.religion) === religionNorm(u.religion)) s += 5;
    return Math.min(100, s);
}

// Optimized helper: Re-uses a single typed array pool to eliminate memory allocations in loops
function sim(a, b) {
    if (!a || !b) return 0;
    if (a === b) return 1;

    if (a.length < b.length) [a, b] = [b, a];

    const lenA = a.length;
    const lenB = b.length;
    let prev = new Int32Array(lenB + 1);
    let cur = new Int32Array(lenB + 1);

    for (let j = 0; j <= lenB; j++) prev[j] = j;

    for (let i = 1; i <= lenA; i++) {
        cur[0] = i;
        for (let j = 1; j <= lenB; j++) {
            const sub = prev[j - 1] + (a.charCodeAt(i - 1) === b.charCodeAt(j - 1) ? 0 : 1);
            cur[j] = Math.min(prev[j] + 1, cur[j - 1] + 1, sub);
        }
        [prev, cur] = [cur, prev];
    }
    return 1 - prev[lenB] / lenA;
}
app.put('/api/remark', (req, res) => {
    try {
        const pspNic = clean(req.body.psp_nic) || null,
            udisePen = clean(req.body.udise_pen) || null,
            text = clean(req.body.remark).slice(0, 1000),
            status = ['PENDING', 'VERIFIED', 'CORRECTION_REQUIRED'].includes(req.body.review_status) ? req.body.review_status : 'PENDING';
        if (!pspNic && !udisePen) return res.status(400).json({
            error: 'PSP NIC या UDISE PEN required'
        });
        let ex = null;
        if (req.body.remark_id) ex = queryOne('SELECT * FROM student_remarks WHERE remark_id=?', [Number(req.body.remark_id)]);
        if (!ex && pspNic) ex = queryOne('SELECT * FROM student_remarks WHERE psp_nic=?', [pspNic]);
        if (!ex && udisePen) ex = queryOne('SELECT * FROM student_remarks WHERE udise_pen=?', [udisePen]);
        if (ex) {
            exec('UPDATE student_remarks SET psp_nic=?,udise_pen=?,remark=?,review_status=?,updated_at=CURRENT_TIMESTAMP WHERE remark_id=?', [pspNic, udisePen, text, status, ex.remark_id]);
        } else {
            exec('INSERT INTO student_remarks(psp_nic,udise_pen,remark,review_status) VALUES(?,?,?,?)', [pspNic, udisePen, text, status]);
        }
        saveDb();
        const saved = queryOne('SELECT * FROM student_remarks WHERE remark_id=?', [ex ? ex.remark_id : queryOne('SELECT last_insert_rowid() id').id]);
        res.json({
            ok: true,
            ...saved
        });
    } catch (e) {
        res.status(500).json({
            error: e.message
        })
    }
});

function sourceExport(type) {
    return tableRows(type);
}
app.get('/api/export/psp.json', (_r, res) => res.json(sourceExport('psp')));
app.get('/api/export/udise.json', (_r, res) => res.json(sourceExport('udise')));
app.get('/api/backup', (_r, res) => {
    saveDb();
    res.download(DB_FILE, 'student_compare.sqlite')
});
async function init() {
    const SQL = await initSqlJs({
        locateFile: f => path.join(ROOT, 'node_modules', 'sql.js', 'dist', f)
    });
    db = fs.existsSync(DB_FILE) ? new SQL.Database(fs.readFileSync(DB_FILE)) : new SQL.Database();
    const required = (table, fields) => {
        const cols = queryAll(`PRAGMA table_info(${qid(table)})`).map(x => x.name);
        return fields.every(f => cols.includes(f));
    };
    const hasP = dbHasTable('psp_student_data'),
        hasU = dbHasTable('udise_data');
    if ((hasP && !required('psp_student_data', PSP_FIELDS)) || (hasU && !required('udise_data', UDISE_FIELDS))) {
        db.run('DROP TABLE IF EXISTS psp_student_data');
        db.run('DROP TABLE IF EXISTS udise_data');
    }
    db.exec(fs.readFileSync(SCHEMA_FILE, 'utf8'));
    saveDb();
    app.listen(PORT, () => console.log(`PSP-UDISE app running on http://localhost:${PORT}`));
}

function dbHasTable(name) {
    return !!queryOne("SELECT name FROM sqlite_master WHERE type='table' AND name=?", [name]);
}
process.on('SIGINT', () => {
    try {
        if (db) saveDb()
    } finally {
        process.exit(0)
    }
});
process.on('SIGTERM', () => {
    try {
        if (db) saveDb()
    } finally {
        process.exit(0)
    }
});
init().catch(e => {
    console.error(e);
    process.exit(1)
});

// ==========================================================
// 1. GLOBAL HELPERS (Fully Optimized Global Scope)
// ==========================================================

function variants(u) {
    return [u.student_name, u.name_as_uuid].map(norm).filter(Boolean);
}

function nameCompat(p, u) {
    const A = norm(p.student_name);
    if (!A) return false;
    for (const B of variants(u)) {
        if (A === B) return true;
        const at = A.split(/\s+/).filter(Boolean);
        const bt = B.split(/\s+/).filter(Boolean);
        if (at.length === 0 || bt.length === 0) continue;
        if (at.every(t => bt.includes(t)) || bt.every(t => at.includes(t))) return true;
        if (at.length === 1 && bt.length === 1 && sim(at[0], bt[0]) >= 0.75) return true;
        if (at.length === bt.length && at.length > 1 && at.every((t, i) => sim(t, bt[i]) >= 0.80)) return true;
    }
    return false;
}

function ev(p, u) {
    const A = p._nameNorm;
    const variants = [u._nameNorm, u._nameUuidNorm].filter(Boolean);
    if (!A || !variants.length) return null;

    const tokenCompat = (x, y) => {
        if (x === y) return true;
        const xt = x.split(' ').filter(Boolean);
        const yt = y.split(' ').filter(Boolean);
        if (!xt.length || !yt.length) return false;

        const short = xt.length <= yt.length ? xt : yt;
        const long = xt.length <= yt.length ? yt : xt;

        if (short.every(t => long.includes(t))) return true;
        if (short.length === 1) return sim(short[0], long[0]) >= 0.75;
        return short.length === long.length &&
            short.every((t, i) => sim(t, long[i]) >= 0.80);
    };

    if (!variants.some(v => tokenCompat(A, v))) return null;

    const ns = Math.max(
        sim(A, u._nameNorm || ''),
        sim(A, u._nameUuidNorm || '')
    );

    const e = {
        nameExact: variants.includes(A),
        nameSim: ns,
        dobSame: !!p._dobNorm && !!u._dobNorm && p._dobNorm === u._dobNorm,
        mobileSame: !!p._mobileDigits && !!u._mobileDigits && p._mobileDigits === u._mobileDigits,
        aadhaarSame: aadhaarState(p, u) === 'MATCH',
        classSame: !!p._classCanon &&
            (p._classCanon === u._classIdCanon || p._classCanon === u._classDescCanon),
        genderSame: !!p._genderNorm && !!u._genderNorm && p._genderNorm === u._genderNorm,
        fatherSame: !!p._fatherNorm && !!u._fatherNorm && p._fatherNorm === u._fatherNorm,
        motherSame: !!p._motherNorm && !!u._motherNorm && p._motherNorm === u._motherNorm,
        categorySame: !!p._categoryNorm && !!u._categoryNorm && p._categoryNorm === u._categoryNorm,
        religionSame: !!p._religionNorm && !!u._religionNorm && p._religionNorm === u._religionNorm
    };

    const parents = Number(e.fatherSame) + Number(e.motherSame);
    const support = Number(e.mobileSame) + Number(e.aadhaarSame) +
        Number(e.classSame) + Number(e.genderSame) + parents;

    let tier = 0;
    if (e.aadhaarSame && (e.dobSame || e.mobileSame || e.classSame || parents >= 1)) tier = 3;
    if (e.nameExact && e.mobileSame && e.classSame && parents >= 1) tier = 3;
    if (e.nameSim >= 0.92 && e.mobileSame && (e.classSame || parents >= 1)) tier = 3;
    if (e.nameExact && e.dobSame && support >= 2) tier = 3;
    if (e.nameSim >= 0.88 && e.dobSame && support >= 2) tier = 3;

    if (tier < 3) {
        if (e.nameExact && e.dobSame && (parents >= 1 || e.mobileSame || e.classSame)) tier = 2;
        else if (e.nameSim >= 0.90 && e.mobileSame && (e.classSame || parents >= 1)) tier = 2;
        else if (e.nameSim >= 0.88 && e.dobSame &&
            (e.mobileSame || parents >= 1 || e.classSame)) tier = 2;
    }

    if (tier < 2 &&
        ((e.nameSim >= 0.92 && e.dobSame) || (e.nameSim >= 0.88 && support >= 2))) {
        tier = 1;
    }

    if (!tier) return null;

    const calculatedScore =
        (e.nameExact ? 35 : Math.round(e.nameSim * 30)) +
        (e.dobSame ? 25 : 0) +
        (e.aadhaarSame ? 20 : 0) +
        (e.mobileSame ? 10 : 0) +
        (e.classSame ? 5 : 0) +
        (e.fatherSame ? 4 : 0) +
        (e.motherSame ? 4 : 0) +
        (e.genderSame ? 2 : 0);

    return { ...e, tier, score: calculatedScore };
}
// Helper to run matching pipeline core logic efficiently
function runMatchingEngine(psp, ud) {
    const udiseByAadhaar = new Map();
    const udiseByInitial = new Map();

    for (let ui = 0; ui < ud.length; ui++) {
        const u = ud[ui];
        if (u.uuid_last4) {
            if (!udiseByAadhaar.has(u.uuid_last4)) udiseByAadhaar.set(u.uuid_last4, []);
            udiseByAadhaar.get(u.uuid_last4).push(ui);
        }
        const uName = norm(u.student_name);
        if (uName) {
            const initial = uName.charAt(0);
            if (!udiseByInitial.has(initial)) udiseByInitial.set(initial, []);
            udiseByInitial.get(initial).push(ui);
        }
    }

    const edges = [];

    for (let pi = 0; pi < psp.length; pi++) {
        const p = psp[pi];
        const candidates = new Set();

        if (p.aadhaar_last4 && udiseByAadhaar.has(p.aadhaar_last4)) {
            udiseByAadhaar.get(p.aadhaar_last4).forEach(ui => candidates.add(ui));
        }
        const pName = norm(p.student_name);
        if (pName) {
            const initial = pName.charAt(0);
            if (udiseByInitial.has(initial)) {
                udiseByInitial.get(initial).forEach(ui => candidates.add(ui));
            }
        }

        for (const ui of candidates) {
            const e = ev(p, ud[ui]);
            if (e) edges.push({ pi, ui, e });
        }
    }
    
    edges.sort((a, b) => b.e.tier - a.e.tier || b.e.score - a.e.score || b.e.nameSim - a.e.nameSim);

    const usedP = new Set();
    const usedU = new Set();
    const rows = [];

    for (const x of edges) {
        if (usedP.has(x.pi) || usedU.has(x.ui)) continue;
        usedP.add(x.pi);
        usedU.add(x.ui);
        const p = psp[x.pi];
        const u = ud[x.ui];
        const diffs = compare(p, u);
        rows.push({
            type: hasCoreIdentityMismatch(diffs) ? 'MISMATCH' : 'MATCHED',
            psp: p,
            udise: u,
            diffs,
            score: score(p, u),
            matchTier: x.e.tier
        });
    }

    const globallyMatchedNICs = new Set();
    const globallyMatchedPENs = new Set();
    for (const x of rows) {
        if (x.psp && x.psp.psp_nic_id) globallyMatchedNICs.add(x.psp.psp_nic_id);
        if (x.udise && x.udise.student_code_nat) globallyMatchedPENs.add(x.udise.student_code_nat);
    }

    for (let pi = 0; pi < psp.length; pi++) {
        if (usedP.has(pi)) continue;
        const p = psp[pi];
        if (p.psp_nic_id && globallyMatchedNICs.has(p.psp_nic_id)) continue;

        const candidates = new Set();
        if (p.aadhaar_last4 && udiseByAadhaar.has(p.aadhaar_last4)) {
            udiseByAadhaar.get(p.aadhaar_last4).forEach(ui => candidates.add(ui));
        }
        const pName = norm(p.student_name);
        if (pName) {
            const initial = pName.charAt(0);
            if (udiseByInitial.has(initial)) {
                udiseByInitial.get(initial).forEach(ui => candidates.add(ui));
            }
        }

        const c = [];
        for (const ui of candidates) {
            if (usedU.has(ui)) continue;
            const u = ud[ui];
            if (u.student_code_nat && globallyMatchedPENs.has(u.student_code_nat)) continue;
            const e = ev(p, u);
            if (e) c.push({ ui, e });
        }

        if (c.length > 0) {
            c.sort((a, b) => b.e.tier - a.e.tier || b.e.score - a.e.score);
            const best = c[0];
            const second = c[1];
            
            if (best && best.e.score >= 70 && (!second || best.e.score - second.e.score >= 12)) {
                usedP.add(pi);
                usedU.add(best.ui);
                const u = ud[best.ui];
                if (p.psp_nic_id) globallyMatchedNICs.add(p.psp_nic_id);
                if (u.student_code_nat) globallyMatchedPENs.add(u.student_code_nat);
                const diffs = compare(p, u);
                rows.push({
                    type: 'POSSIBLE_MATCH',
                    psp: p,
                    udise: u,
                    diffs: ['REVIEW_MATCH', ...diffs],
                    score: score(p, u),
                    matchTier: best.e.tier
                });
                continue;
            }
        }

        rows.push({
            type: 'NOT_IN_UDISE',
            psp: p,
            udise: null,
            diffs: ['PSP_BUT_NOT_IN_UDISE'],
            score: 0
        });
    }

    for (let ui = 0; ui < ud.length; ui++) {
        if (!usedU.has(ui)) {
            rows.push({
                type: 'NOT_IN_PSP',
                psp: null,
                udise: ud[ui],
                diffs: ['UDISE_BUT_NOT_IN_PSP'],
                score: 0
            });
        }
    }
    // --- GLOBAL CLASS & ALPHABETICAL SORTING ENGINE PASS ---
    rows.sort((a, b) => {
        // 1. Safely derive clean numeric identifiers out of whichever data profile side is present
        const aObj = a.psp || a.udise;
        const bObj = b.psp || b.udise;
        
        if (!aObj) return 1;
        if (!bObj) return -1;
        
        const aClassStr = a.psp ? a.psp.studying_class : (a.udise.class_desc || a.udise.class_id);
        const bClassStr = b.psp ? b.psp.studying_class : (b.udise.class_desc || b.udise.class_id);
        
        // Convert using your existing classNum function (defaults to 999 if unresolvable)
        const aClassNum = classNum(aClassStr) !== null ? classNum(aClassStr) : 999;
        const bClassNum = classNum(bClassStr) !== null ? classNum(bClassStr) : 999;
        
        // 2. Evaluate Class Sort Order
        if (aClassNum !== bClassNum) {
            return aClassNum - bClassNum;
        }
        
        // 3. Alphabetical Fallback (Evaluates name tokens safely from A to Z)
        const aName = norm(aObj.student_name || '');
        const bName = norm(bObj.student_name || '');
        
        return aName.localeCompare(bName);
    });

    return rows;
}

function prepareRowsForSearch(rows) {
    for (const row of rows) {
        const p = row.psp;
        const u = row.udise;
        const values = [
            p?.psp_nic_id, p?.sr_no, p?.student_name, p?.father_name, p?.mother_name,
            p?.mobile, p?.aadhaar_last4, p?.studying_class, p?.social_category, p?.religion,
            u?.student_id, u?.student_code_nat, u?.student_name, u?.father_name, u?.mother_name,
            u?.mobile, u?.uuid_last4, u?.class_id, u?.class_desc, u?.social_category, u?.religion
        ];
        Object.defineProperty(row, '_searchText', {
            value: norm(values.filter(Boolean).join(' ')),
            enumerable: false
        });
    }
    return rows;
}

// ==========================================================
// 3. REFACTORED APIS COMPARE ROUTE
// ==========================================================
app.get('/api/compare', (req, res) => {
    try {
        if (!comparisonCache) {
            const psp = tableRows('psp').map(pspMap);
            const udise = tableRows('udise').map(udiseMap);
            const rows = prepareRowsForSearch(runMatchingEngine(psp, udise));

            const counts = {
                ALL: rows.length,
                MATCHED: 0,
                MISMATCH: 0,
                POSSIBLE_MATCH: 0,
                NOT_IN_UDISE: 0,
                NOT_IN_PSP: 0
            };

            for (const row of rows) {
                counts[row.type] = (counts[row.type] || 0) + 1;
                for (const diff of row.diffs || []) counts[diff] = (counts[diff] || 0) + 1;
            }

            comparisonCache = {
                rows,
                counts,
                totals: { psp: psp.length, udise: udise.length }
            };
        }

        const filter = clean(req.query.filter || 'ALL');
        const classFilter = clean(req.query.class || '');
        const q = norm(req.query.q || '');

        let rows = comparisonCache.rows;

        if (filter !== 'ALL') {
            rows = rows.filter(row =>
                row.type === filter || (row.diffs || []).includes(filter)
            );
        }

        if (classFilter) {
            const wanted = classCanon(classFilter);
            rows = rows.filter(row => {
                const pClass = row.psp ? classCanon(row.psp.studying_class) : '';
                const uClass = row.udise ? classCanon(row.udise.class_desc || row.udise.class_id) : '';
                return pClass === wanted || uClass === wanted;
            });
        }

        if (q) rows = rows.filter(row => row._searchText.includes(q));

        const remarks = queryAll(
            'SELECT remark_id, psp_nic, udise_pen, remark, review_status, updated_at FROM student_remarks'
        );
        const byP = new Map();
        const byU = new Map();

        for (const r of remarks) {
            if (r.psp_nic) byP.set(norm(r.psp_nic), r);
            if (r.udise_pen) byU.set(norm(r.udise_pen), r);
        }

        for (const row of rows) {
            row.remark =
                (row.psp && byP.get(norm(row.psp.psp_nic_id))) ||
                (row.udise && byU.get(norm(row.udise.student_code_nat))) ||
                null;
        }

        res.json({
            counts: comparisonCache.counts,
            rows,
            totals: comparisonCache.totals
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});
// ==========================================================
// 4. HIGH-SPEED STREAMING EXPORT ROUTE
// ==========================================================
app.get('/api/export/mismatch.csv', (req, res) => {
    try {
        const psp = tableRows('psp').map(pspMap);
        const ud = tableRows('udise').map(udiseMap);
        res.setHeader('Content-Type', 'text/csv; charset=utf-8');
        res.setHeader('Content-Disposition', 'attachment; filename=student_mismatch_report.csv');

        res.write('\uFEFF');

        const headers = [
            "Status Tier", "PSP NIC ID", "UDISE PEN", "Student Name (PSP)", "Student Name (UDISE)",
            "Class (PSP)", "Class (UDISE)", "DOB (PSP)", "DOB (UDISE)", "Category (PSP)", "Category (UDISE)", "Religion (PSP)", "Religion (UDISE)",
            "Identified Mismatches"
        ];
        res.write(headers.map(h => `"${h.replace(/"/g, '""')}"`).join(',') + '\n');

        const rows = runMatchingEngine(psp, ud);
        const classFilter = clean(req.query.class || ''); // Read class parameter for export

        for (const row of rows) {
            if (row.type === 'MATCHED') continue;

            // Skip rows that don't match the selected class
            if (classFilter) {
                const pspClass = row.psp ? classCanon(row.psp.studying_class) : '';
                const udiseClass = row.udise ? classCanon(row.udise.class_desc || row.udise.class_id) : '';
                if (pspClass !== classCanon(classFilter) && udiseClass !== classCanon(classFilter)) {
                    continue;
                }
            }

            const csvLine = [
            row.type,row.psp ? row.psp.psp_nic_id : '',
            row.udise ? row.udise.student_code_nat : '',
            row.psp ? row.psp.student_name : '',
            row.udise ? row.udise.student_name : '',
            row.psp ? row.psp.studying_class : '',
            row.udise ? row.udise.class_desc : '',
            row.psp ? row.psp.dob : '',
            row.udise ? row.udise.dob : '',
            row.diffs ? row.diffs.join('; ') : '',
            row.psp ? row.psp.social_category : '', // <-- नया
            row.udise ? row.udise.social_category : '', // <-- नया
            row.psp ? row.psp.religion : '', // <-- नया
            row.udise ? row.udise.religion : '', // <-- नया
            ];
            res.write(csvLine.map(v => `"${String(v || '').replace(/"/g, '""')}"`).join(',') + '\n');
        }

        res.end();
    } catch (e) {
        console.error("Export Error: ", e.message);
        if (!res.headersSent) {
            res.status(500).send("Failed to generate file due to system mismatch.");
        }
    }
});
