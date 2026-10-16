/* Canonical reports and operational planning. No client-side metric substitutes. */
async function downloadCenterFile(request, preview = false) {
    const ticket = await apiRequest('/exports/ticket', 'POST', request);
    const response = await fetch(new URL(ticket.url, API_BASE), {cache: 'no-store'});
    if (!response.ok) throw new Error('تعذر تنزيل الملف. أعد المحاولة.');
    const url = URL.createObjectURL(await response.blob());
    if (preview) return url;
    const link = document.createElement('a'); link.href = url; link.download = ticket.fileName;
    document.body.appendChild(link); link.click(); link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 60000);
}

function currentReportFilter(kind) {
    return {
        kind: kind || document.getElementById('dyn-report-preset-type')?.value || 'all',
        from: document.getElementById('unified-report-from')?.value || null,
        to: document.getElementById('unified-report-to')?.value || null,
        circleId: Number(document.getElementById('dyn-filter-circle')?.value) || null,
        absenceThreshold: Number(document.getElementById('unified-absence-threshold')?.value) || 3,
        studentIds: typeof currentDynamicFilteredStudents !== 'undefined' ? currentDynamicFilteredStudents.map(s => s.id) : null
    };
}
async function exportUnifiedReport(format = 'xlsx', kind) {
    try { await downloadCenterFile({filter: currentReportFilter(kind), format}); }
    catch (e) { showAlert(e.message, 'danger'); }
}
async function previewUnifiedReport() {
    try {
        const data = await apiRequest('/exports/preview', 'POST', currentReportFilter());
        document.getElementById('unified-report-result').innerHTML = `<h4>${escapeXml(data.title)}</h4><p class="text-muted">${escapeXml(data.period)}</p>
        <div class="table-responsive"><table class="table table-striped"><thead><tr>${data.columns.map(c => `<th>${escapeXml(c)}</th>`).join('')}</tr></thead>
        <tbody>${data.rows.map(r => `<tr>${r.map(c => `<td>${escapeXml(c)}</td>`).join('')}</tr>`).join('') || '<tr><td>لا توجد سجلات مطابقة.</td></tr>'}</tbody></table></div>`;
    } catch (e) { showAlert(e.message, 'danger'); }
}
function installOperationalTools() {
    const reports = document.getElementById('dynamic-reports-section');
    if (reports && !document.getElementById('unified-report-result')) {
        const panel = document.createElement('div'); panel.className = 'operations-panel';
        panel.innerHTML = `<h3>تقارير السجلات الفعلية</h3><p>اختر نوع التقرير من القائمة، ثم الفترة والحلقة. المعاينة وملفات التنزيل تستخدم السجلات نفسها.</p>
        <div class="operations-fields"><label>من تاريخ<input type="date" id="unified-report-from" class="form-control"></label>
        <label>إلى تاريخ<input type="date" id="unified-report-to" class="form-control"></label>
        <label>حد الغياب<input type="number" min="1" value="3" id="unified-absence-threshold" class="form-control"></label></div>
        <div class="operations-actions"><button class="btn btn-primary" onclick="previewUnifiedReport()">معاينة التقرير</button>
        <button class="btn btn-success" onclick="exportUnifiedReport('xlsx')">تنزيل Excel</button><button class="btn btn-outline-danger" onclick="exportUnifiedReport('pdf')">تنزيل PDF</button></div><div id="unified-report-result" aria-live="polite"></div>`;
        const reportsHeader = reports.querySelector('.section-header');
        if (reportsHeader) reportsHeader.insertAdjacentElement('afterend', panel);
        else reports.prepend(panel);
    }
    const quality = document.getElementById('quality-management-section');
    if (quality && !document.getElementById('operations-open-button')) {
        const button = document.createElement('button'); button.id = 'operations-open-button';
        button.className = 'btn btn-primary mb-3'; button.textContent = 'خطط الحلقات والمواعيد وحضور المعلمين';
        button.onclick = showCenterOperations; quality.prepend(button);
    }
}

async function showCenterOperations() {
    try {
        const [circles, plans, schedules, days] = await Promise.all(['/circles','/operations/plans','/operations/schedules','/operations/days'].map(p => apiRequest(p)));
        const names = new Map(circles.map(c => [c.id, c.name]));
        const admin = ['Admin', 'Developer'].includes(currentRole);
        await Swal.fire({title:'إدارة الخطط والتشغيل', width:1000, showConfirmButton:false, showCloseButton:true,
            html:`<div class="operations-modal" dir="rtl">
            <p>التوقيت المحلي للمركز. الأيام: 1 الاثنين، 2 الثلاثاء، …، 7 الأحد. لا يُحتسب التأخير دون موعد مسجل.</p>
            ${admin ? `<div class="operations-fields"><label>الحلقة<select id="ops-circle" class="form-select">${circles.map(c => `<option value="${c.id}">${escapeXml(c.name)}</option>`).join('')}</select></label>
            <label>الأيام<input id="ops-days" class="form-control" value="1,2,3,4,7"></label><label>موعد البدء<input type="time" id="ops-time" class="form-control" value="16:00"></label>
            <label>السعة<input type="number" id="ops-capacity" min="1" class="form-control" value="20"></label></div>
            <button class="btn btn-outline-success" onclick="saveOperationalSchedule()">حفظ موعد الحلقة</button>
            <hr><div class="operations-fields"><label>اسم الخطة<input id="ops-title" class="form-control" placeholder="خطة هذا الشهر"></label>
            <label>المسار<select id="ops-track" class="form-select"><option value="Quran">قرآن</option><option value="Aqeedah">عقيدة</option><option value="Tajweed">أحكام وتجويد</option><option value="Course">دورة دينية</option></select></label>
            <label>البداية<input type="date" id="ops-from" class="form-control"></label><label>النهاية<input type="date" id="ops-to" class="form-control"></label>
            <label>الهدف<input type="number" id="ops-target" class="form-control" min="1"></label><label>المنجز<input type="number" id="ops-completed" class="form-control" min="0" value="0"></label>
            <label>وحدة القياس<input id="ops-unit" class="form-control" value="صفحة"></label></div>
            <button class="btn btn-success" onclick="saveOperationalPlan()">إضافة الخطة</button><hr>
            <button class="btn btn-outline-danger" onclick="recordTeacherAbsence()">تسجيل غياب معلم الحلقة المختارة اليوم</button>` : ''}
            <h4 class="mt-4">الخطط المسجلة</h4><div class="operations-grid">${plans.map(p => `<article><b>${escapeXml(names.get(p.circleId) || '')} • ${escapeXml(p.title)}</b><p>${escapeXml(p.startsOn)} — ${escapeXml(p.endsOn)}</p><p>${p.completed} / ${p.target} ${escapeXml(p.unit)}</p>${admin ? `<button class="btn btn-sm btn-outline-primary" onclick='updateOperationalPlan(${p.id})'>تحديث الإنجاز</button>` : ''}</article>`).join('') || 'لم تسجل خطط بعد.'}</div>
            <h4 class="mt-4">المواعيد</h4>${schedules.map(s => `<p>${escapeXml(names.get(s.circleId) || '')}: ${escapeXml(s.startTime)} • السعة ${s.capacity}</p>`).join('')}
            <h4>سجل التشغيل</h4><div class="table-responsive"><table class="table"><tbody>${days.map(d => `<tr><td>${escapeXml(names.get(d.circleId) || '')}</td><td>${escapeXml(d.date)}</td><td>${escapeXml(d.status)}</td><td>${d.openedAt ? new Date(d.openedAt).toLocaleTimeString('ar') : 'لم تبدأ'}</td></tr>`).join('')}</tbody></table></div></div>`});
    } catch (e) { showAlert(e.message, 'danger'); }
}
async function saveOperationalSchedule() {
    try { await apiRequest('/operations/schedules','POST',{circleId:Number(document.getElementById('ops-circle').value),weekdays:document.getElementById('ops-days').value,startTime:document.getElementById('ops-time').value,capacity:Number(document.getElementById('ops-capacity').value),durationMinutes:60}); Swal.close(); showCenterOperations(); }
    catch(e) { showAlert(e.message,'danger'); }
}
async function saveOperationalPlan() {
    try { await apiRequest('/operations/plans','POST',{circleId:Number(document.getElementById('ops-circle').value),title:document.getElementById('ops-title').value,track:document.getElementById('ops-track').value,startsOn:document.getElementById('ops-from').value,endsOn:document.getElementById('ops-to').value,target:Number(document.getElementById('ops-target').value),completed:Number(document.getElementById('ops-completed').value),unit:document.getElementById('ops-unit').value}); Swal.close(); showCenterOperations(); }
    catch(e) { showAlert(e.message,'danger'); }
}
async function updateOperationalPlan(id) {
    const plans = await apiRequest('/operations/plans'); const plan = plans.find(p => p.id === id);
    const answer = await Swal.fire({title:plan.title,input:'number',inputValue:plan.completed,inputAttributes:{min:0,max:plan.target,step:'0.5'},showCancelButton:true,confirmButtonText:'حفظ الإنجاز'});
    if(answer.isConfirmed) { try { await apiRequest('/operations/plans','POST',{...plan,completed:Number(answer.value)}); showCenterOperations(); } catch(e){showAlert(e.message,'danger');} }
}
async function recordTeacherAbsence() {
    const circleId = Number(document.getElementById('ops-circle').value);
    const answer = await Swal.fire({title:'سبب غياب المعلم',input:'text',showCancelButton:true,confirmButtonText:'تسجيل الغياب'});
    if(answer.isConfirmed && answer.value?.trim()) { try { const today = await apiRequest('/operations/today'); await apiRequest(`/operations/days/${circleId}`,'POST',{date:today.date,status:'Absent',reason:answer.value}); showCenterOperations(); } catch(e){showAlert(e.message,'danger');} }
}
async function showUnifiedCertificate(kind, id) {
    let previewUrl;
    const request = {certificateKind:kind,certificateId:Number(id)};
    try {
        Swal.fire({title:'جاري تجهيز الشهادة',html:'<p>لحظات ونفتح المعاينة…</p><div class="spinner-border text-success" role="status"></div>',showConfirmButton:false,showCloseButton:true,allowOutsideClick:false});
        previewUrl = await downloadCenterFile({...request,format:'png'},true);
        Swal.update({title:'شهادة الإنجاز',width:1050,showConfirmButton:false,showCloseButton:true,allowOutsideClick:true,
            html:`<div class="operations-actions"><button class="btn btn-success" id="unified-cert-download">تنزيل PDF</button><button class="btn btn-outline-primary" id="unified-cert-print">عرض للطباعة</button></div><img src="${previewUrl}" alt="معاينة الشهادة المطابقة لملف التنزيل" style="display:block;width:100%;max-height:65vh;object-fit:contain">`,
        });
        document.getElementById('unified-cert-download').onclick=()=>downloadCenterFile({...request,format:'pdf'}).catch(e=>showAlert(e.message,'danger'));
        document.getElementById('unified-cert-print').onclick=async()=>{
                    const printWindow=window.open('','_blank');
                    if(!printWindow){showAlert('يرجى السماح بفتح نافذة الطباعة.','warning');return;}
                    try {const pdfUrl=await downloadCenterFile({...request,format:'pdf'},true);
                        printWindow.location.href=pdfUrl;setTimeout(()=>URL.revokeObjectURL(pdfUrl),120000);
                    }catch(e){printWindow.close();showAlert(e.message,'danger');}
        };
    } catch(e) { showAlert(e.message,'danger'); }
    finally { if(previewUrl) setTimeout(()=>URL.revokeObjectURL(previewUrl),120000); }
}
document.addEventListener('DOMContentLoaded',installOperationalTools);
