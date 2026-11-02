const { test } = require('node:test');
const assert = require('node:assert/strict');
const rules = require('../QuranCircles.Web/registration-fields.js');

test('Identity comparison matches the complete nine digits only', () => {
    assert.equal(rules.sameIdentity('123456789', '123456788'), false);
    assert.equal(rules.sameIdentity('1', '1'), false);
    assert.equal(rules.sameIdentity('١٢٣٤٥٦٧٨٩', '123456789'), true);
    for (const number of ['12345678', '1234567890']) assert.ok(rules.identityError(number));
});
test('Family phone accepts the two local prefixes and exact length', () => {
    for (const number of ['0591234567', '0561234567']) assert.equal(rules.phoneError(number, true), '');
    for (const number of ['0571234567', '059123456', '05912345678']) assert.ok(rules.phoneError(number, true));
});
test('WhatsApp preserves country choices and supports previous stored formats', () => {
    assert.deepEqual(rules.splitWhatsApp('00972591234567'), {code: '+972', number: '591234567'});
    assert.deepEqual(rules.splitWhatsApp('0591234567'), {code: '+970', number: '591234567'});
    assert.equal(rules.whatsAppError(''), '');
    assert.ok(rules.whatsAppError('12345678'));
});
