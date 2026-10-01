'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const htmlPath = path.join(__dirname, '..', 'index.html');
const html = fs.readFileSync(htmlPath, 'utf8');
const start = html.indexOf('const qid = s =>');
const end = html.indexOf('function prepareRowsForSearch', start);

assert.notEqual(start, -1, 'Could not locate the comparison helper section in index.html');
assert.notEqual(end, -1, 'Could not locate the end of the comparison engine section');
const engineSource = html.slice(start, end);
const sandbox = { console };
vm.createContext(sandbox);
vm.runInContext(engineSource + '\nglobalThis.__engine = { runMatchingEngine, compare, hasCoreIdentityMismatch };', sandbox);
const engine = sandbox.__engine;

function psp(overrides = {}) {
  const p = {
    psp_nic_id: 'NIC-001', sr_no: '1', aadhaar_last4: '1234',
    student_name: 'Aarav Kumar', father_name: 'Raj Kumar', mother_name: 'Sita Kumar',
    dob: '01/02/2010', gender: 'MALE', studying_class: '5', mobile: '9876543210',
    social_category: 'GENERAL', religion: 'HINDU',
    _nameNorm: 'AARAV KUMAR', _fatherNorm: 'RAJ KUMAR', _motherNorm: 'SITA KUMAR',
    _dobNorm: '01/02/2010', _genderNorm: 'MALE', _mobileDigits: '9876543210',
    _classCanon: '5', _categoryNorm: 'GENERAL', _religionNorm: 'HINDU'
  };
  return { ...p, ...overrides };
}

function udise(overrides = {}) {
  const u = {
    student_code_nat: 'PEN-001', uuid_last4: '1234',
    student_name: 'Aarav Kumar', name_as_uuid: 'Aarav Kumar',
    father_name: 'Raj Kumar', mother_name: 'Sita Kumar',
    dob: '01/02/2010', gender: 'MALE', class_id: '5', class_desc: 'Class 5',
    mobile: '9876543210', social_category: 'GENERAL', religion: 'HINDU',
    _nameNorm: 'AARAV KUMAR', _nameUuidNorm: 'AARAV KUMAR',
    _fatherNorm: 'RAJ KUMAR', _motherNorm: 'SITA KUMAR',
    _dobNorm: '01/02/2010', _genderNorm: 'MALE', _mobileDigits: '9876543210',
    _classIdCanon: '5', _classDescCanon: '5',
    _categoryNorm: 'GENERAL', _religionNorm: 'HINDU'
  };
  return { ...u, ...overrides };
}

test('baseline: identical student records remain matched', () => {
  const rows = engine.runMatchingEngine([psp()], [udise()]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].type, 'MATCHED');
  assert.equal(rows[0].psp.psp_nic_id, 'NIC-001');
  assert.equal(rows[0].udise.student_code_nat, 'PEN-001');
  assert.deepEqual(Array.from(rows[0].diffs), []);
});

test('baseline: core identity difference remains a mismatch, not an unmatched record', () => {
  const rows = engine.runMatchingEngine(
    [psp()],
    [udise({ dob: '03/04/2011', _dobNorm: '03/04/2011' })]
  );
  assert.equal(rows.length, 1);
  assert.equal(rows[0].type, 'MISMATCH');
  assert.ok(Array.from(rows[0].diffs).includes('DOB_MISMATCH'));
});

test('baseline: records with unrelated names and identifiers remain on their respective sides', () => {
  const rows = engine.runMatchingEngine(
    [psp({ student_name: 'Aarav Kumar', _nameNorm: 'AARAV KUMAR', aadhaar_last4: '1234' })],
    [udise({ student_name: 'Zoya Khan', name_as_uuid: 'Zoya Khan', _nameNorm: 'ZOYA KHAN', _nameUuidNorm: 'ZOYA KHAN', uuid_last4: '9876' })]
  );
  assert.equal(rows.length, 2);
  assert.equal(rows.filter(r => r.type === 'NOT_IN_UDISE').length, 1);
  assert.equal(rows.filter(r => r.type === 'NOT_IN_PSP').length, 1);
});

test('baseline: one UDISE record is never assigned to two PSP records', () => {
  const first = psp({ psp_nic_id: 'NIC-001' });
  const second = psp({ psp_nic_id: 'NIC-002', sr_no: '2' });
  const rows = engine.runMatchingEngine([first, second], [udise()]);
  assert.equal(rows.length, 2);
  assert.equal(rows.filter(r => r.udise && r.udise.student_code_nat === 'PEN-001').length, 1);
  assert.equal(rows.filter(r => r.type === 'NOT_IN_UDISE').length, 1);
  assert.equal(rows.filter(r => r.type === 'NOT_IN_PSP').length, 0);
});
