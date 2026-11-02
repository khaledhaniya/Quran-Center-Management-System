(function (root) {
    'use strict';
    const digits = value => String(value ?? '').replace(/[٠-٩۰-۹]/g, c => String(c.charCodeAt(0) - (c >= '۰' ? 0x6f0 : 0x660)));
    const identityError = (value, required = false) => (!digits(value).trim() && !required) || /^[0-9]{9}$/.test(digits(value).trim()) ? '' : 'رقم الهوية يجب أن يكون 9 أرقام بالضبط.';
    const sameIdentity = (a, b) => !identityError(a, true) && !identityError(b, true) && digits(a).trim() === digits(b).trim();
    const phoneError = (value, required = false) => (!digits(value).trim() && !required) || /^05[69][0-9]{7}$/.test(digits(value).trim()) ? '' : 'رقم الجوال 10 أرقام يبدأ بـ 059 أو 056.';
    function splitWhatsApp(value) {
        let number = digits(value).replace(/[\s()+-]/g, ''), code = '+970';
        if (number.startsWith('00')) number = number.slice(2);
        if (/^97[02]/.test(number)) { code = '+' + number.slice(0, 3); number = number.slice(3); }
        return { code, number: number.replace(/^0/, '') };
    }
    const whatsAppError = value => !String(value ?? '').trim() || /^5[0-9]{8}$/.test(splitWhatsApp(value).number) ? '' : 'أدخل رقم جوال صحيح للواتساب.';
    const rules = { digits, identityError, sameIdentity, phoneError, splitWhatsApp, whatsAppError, defaultPassword: '123456' };
    if (typeof module !== 'undefined') module.exports = rules;
    if (!root.document) return;
    root.RegistrationFields = rules;
    const identityIds = new Set(['student-id-num', 'student-parent-id', 'swal-tch-id', 'req-student-id-num', 'req-parent-id-num', 'swal-huffaz-external-id']);
    const phoneIds = new Set(['student-contact', 'swal-tch-phone', 'req-family-contact', 'req-student-mobile', 'swal-huffaz-external-phone']);
    const whatsAppIds = new Set(['student-whatsapp', 'swal-tch-whatsapp', 'req-whatsapp', 'req-student-whatsapp']);
    function feedback(input, message) {
        const error = document.getElementById(input.id + '-feedback');
        if (error) { error.textContent = message; error.hidden = !message; }
        input.classList.toggle('field-invalid', !!message);
        input.setAttribute('aria-invalid', String(!!message));
        input.setCustomValidity(message);
    }
    function errorFor(input) {
        if (input.dataset.registrationKind === 'identity') return identityError(input.value, input.required);
        if (input.dataset.registrationKind === 'phone') return phoneError(input.value, input.required);
        return whatsAppError(input.value);
    }
    function enhance(scope = document) {
        const inputs = scope.matches?.('input') ? [scope] : scope.querySelectorAll?.('input') || [];
        for (const input of inputs) {
            const kind = identityIds.has(input.id) ? 'identity' : phoneIds.has(input.id) ? 'phone' : whatsAppIds.has(input.id) ? 'whatsapp' : null;
            if (!kind || input.dataset.registrationKind) continue;
            input.dataset.registrationKind = kind;
            input.type = 'text'; input.inputMode = 'numeric'; input.dir = 'ltr';
            input.maxLength = kind === 'identity' ? 9 : 10;
            input.autocomplete = 'off';
            input.value = digits(input.value);
            let group = input.closest('.input-icon-wrapper') || input.parentElement;
            let feedbackAnchor = input.closest('.input-icon-wrapper') || input;
            if (kind === 'whatsapp') {
                const parts = splitWhatsApp(input.value);
                const control = document.createElement('div'); control.className = 'contact-number-control'; control.dir = 'ltr';
                const select = document.createElement('select'); select.id = input.id + '-country';
                select.className = 'country-code-select'; select.setAttribute('aria-label', 'مقدمة دولة الواتساب');
                for (const code of ['+970', '+972']) { const option = document.createElement('option'); option.value = code; option.textContent = code; select.append(option); }
                select.value = parts.code;
                input.value = parts.number; input.placeholder = '59xxxxxxx';
                input.before(control); control.append(select, input); group.classList.add('has-country-selector');
                feedbackAnchor = input.closest('.input-icon-wrapper') || control;
                select.addEventListener('change', () => feedback(input, errorFor(input)));
            }
            const small = document.createElement('small'); small.id = input.id + '-feedback'; small.className = 'field-validation-hint'; small.hidden = true;
            small.setAttribute('role', 'status'); feedbackAnchor.after(small); input.setAttribute('aria-describedby', small.id);
            input.addEventListener('input', () => {
                input.value = digits(input.value).replace(/[^0-9]/g, '').slice(0, input.maxLength);
                if (input.dataset.validationTouched) feedback(input, errorFor(input)); else feedback(input, '');
            });
            input.addEventListener('blur', () => { input.dataset.validationTouched = 'true'; feedback(input, errorFor(input)); });
        }
    }
    rules.enhance = enhance;
    rules.readWhatsApp = id => {
        const input = document.getElementById(id); if (!input?.value.trim()) return '';
        const code = document.getElementById(id + '-country')?.value || splitWhatsApp(input.value).code;
        return code + splitWhatsApp(input.value).number;
    };
    rules.validate = scope => {
        enhance(scope);
        let first = null;
        for (const input of scope.querySelectorAll('input[data-registration-kind]')) {
            const message = errorFor(input); feedback(input, message);
            if (message && !first) first = input;
        }
        if (first) {
            const pane = first.closest('.student-tab-pane');
            if (pane) (scope.closest('#modal-body-content') || scope).querySelector(`[data-tab="${pane.id}"]`)?.click();
            first.focus(); first.scrollIntoView({ block: 'center', behavior: 'smooth' });
        }
        return !first;
    };
    document.addEventListener('submit', event => {
        if (event.target.matches('form') && !rules.validate(event.target)) { event.preventDefault(); event.stopImmediatePropagation(); }
    }, true);
    function start() {
        enhance();
        new MutationObserver(records => records.forEach(record => record.addedNodes.forEach(node => { if (node.nodeType === 1) enhance(node); })))
            .observe(document.body, { childList: true, subtree: true });
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})(typeof window !== 'undefined' ? window : globalThis);
