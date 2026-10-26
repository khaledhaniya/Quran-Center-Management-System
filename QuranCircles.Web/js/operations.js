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

function installOperationalTools() {
    installReportCenter();
    const quality = document.getElementById('quality-management-section');
    if (quality && !document.getElementById('operations-open-button')) {
        const button = document.createElement('button'); button.id = 'operations-open-button';
        button.className = 'btn btn-primary mb-3'; button.textContent = 'خطط الحلقات والدورات والمواعيد وحضور المعلمين';
        button.onclick = showCenterOperations; quality.prepend(button);
    }
}

async function showCenterOperations() {
    try {
        const [overview, plans, schedules, days] = await Promise.all(['/operations/plan-targets','/operations/plans','/operations/schedules','/operations/days'].map(p => apiRequest(p)));
        const circles = overview.circles || [], courses = overview.courses || [];
        const names = new Map(circles.map(c => [c.id, c.name]));
        const courseNames = new Map(courses.map(c => [c.id, c.name]));
        const admin = ['Admin', 'Developer'].includes(currentRole);
        const canPlan = admin || teacherCan('quality');
        await Swal.fire({title:'إدارة الخطط والتشغيل', width:1000, showConfirmButton:false, showCloseButton:true,
            html:`<div class="operations-modal" dir="rtl">
            <p>حدد هدف التسميع للحلقة أو هدف الدروس للدورة، ثم حدّث المنجز دوريًا. التوقيت المحلي للمركز؛ الأيام من الاثنين 1 إلى الأحد 7.</p>
            ${admin ? `<div class="operations-fields"><label>الحلقة<select id="ops-circle" class="form-select">${circles.map(c => `<option value="${c.id}">${escapeXml(c.name)}</option>`).join('')}</select></label>
            <label>الأيام<input id="ops-days" class="form-control" value="1,2,3,4,7"></label><label>موعد البدء<input type="time" id="ops-time" class="form-control" value="16:00"></label>
            <label>السعة<input type="number" id="ops-capacity" min="1" class="form-control" value="20"></label></div>
            <button class="btn btn-outline-success" onclick="saveOperationalSchedule()">حفظ موعد الحلقة</button><hr>` : ''}
            ${canPlan ? `<div class="operations-fields"><label>اسم الخطة<input id="ops-title" class="form-control" placeholder="خطة هذا الشهر"></label>
            <label>نوع الخطة<select id="ops-track" class="form-select" onchange="toggleOperationalPlanTarget()">${circles.length ? '<option value="Quran">تسميع القرآن في الحلقة</option><option value="Aqeedah">عقيدة في الحلقة</option><option value="Tajweed">أحكام وتجويد في الحلقة</option>' : ''}${courses.length ? '<option value="Course">دروس دورة محددة</option>' : ''}</select></label>
            <label id="ops-plan-circle-label" ${circles.length ? '' : 'hidden'}>الحلقة<select id="ops-plan-circle" class="form-select">${circles.map(c => `<option value="${c.id}">${escapeXml(c.name)}</option>`).join('')}</select></label>
            <label id="ops-plan-course-label" ${circles.length ? 'hidden' : ''}>الدورة<select id="ops-plan-course" class="form-select">${courses.map(c => `<option value="${c.id}">${escapeXml(c.name)}</option>`).join('')}</select></label>
            <label>البداية<input type="date" id="ops-from" class="form-control" value="${new Date().toISOString().slice(0,10)}"></label><label>النهاية<input type="date" id="ops-to" class="form-control" value="${new Date(Date.now()+30*86400000).toISOString().slice(0,10)}"></label>
            <label>الهدف<input type="number" id="ops-target" class="form-control" min="1"></label><label>المنجز<input type="number" id="ops-completed" class="form-control" min="0" value="0"></label>
            <label>وحدة القياس<input id="ops-unit" class="form-control" value="${circles.length ? 'صفحة' : 'درس'}"></label></div>
            <button class="btn btn-success" onclick="saveOperationalPlan()" ${circles.length || courses.length ? '' : 'disabled'}>إضافة الخطة</button><hr>` : ''}
            ${admin ? `<button class="btn btn-outline-danger" onclick="recordTeacherAbsence()">تسجيل غياب معلم الحلقة المختارة اليوم</button>` : ''}
            <h4 class="mt-4">الخطط المسجلة</h4><div class="operations-grid">${plans.map(p => `<article><b>${escapeXml(p.courseId ? courseNames.get(p.courseId) || 'دورة' : names.get(p.circleId) || 'حلقة')} • ${escapeXml(p.title)}</b><p>${escapeXml(p.startsOn)} — ${escapeXml(p.endsOn)}</p><p>${p.completed} / ${p.target} ${escapeXml(p.unit)}</p><progress max="${p.target}" value="${p.completed}" style="width:100%"></progress>${canPlan ? `<button class="btn btn-sm btn-outline-primary" onclick='updateOperationalPlan(${p.id})'>تحديث الإنجاز</button>` : ''}</article>`).join('') || '<p>لا توجد خطط بعد. أضف خطة للتسميع أو لدورة من الحقول أعلاه.</p>'}</div>
            <h4 class="mt-4">المواعيد</h4>${schedules.map(s => `<p>${escapeXml(names.get(s.circleId) || '')}: ${escapeXml(s.startTime)} • السعة ${s.capacity}</p>`).join('')}
            <h4>سجل التشغيل</h4><div class="table-responsive"><table class="table"><tbody>${days.map(d => `<tr><td>${escapeXml(names.get(d.circleId) || '')}</td><td>${escapeXml(d.date)}</td><td>${escapeXml(d.status)}</td><td>${d.openedAt ? new Date(d.openedAt).toLocaleTimeString('ar') : 'لم تبدأ'}</td></tr>`).join('')}</tbody></table></div></div>`});
    } catch (e) { showAlert(e.message, 'danger'); }
}
function toggleOperationalPlanTarget(){const course=document.getElementById('ops-track')?.value==='Course';document.getElementById('ops-plan-circle-label').hidden=course;document.getElementById('ops-plan-course-label').hidden=!course;document.getElementById('ops-unit').value=course?'درس':'صفحة';}
async function saveOperationalSchedule() {
    try { await apiRequest('/operations/schedules','POST',{circleId:Number(document.getElementById('ops-circle').value),weekdays:document.getElementById('ops-days').value,startTime:document.getElementById('ops-time').value,capacity:Number(document.getElementById('ops-capacity').value),durationMinutes:60}); Swal.close(); showCenterOperations(); }
    catch(e) { showAlert(e.message,'danger'); }
}
async function saveOperationalPlan() {
    try { const track=document.getElementById('ops-track').value; await apiRequest('/operations/plans','POST',{circleId:track==='Course'?0:Number(document.getElementById('ops-plan-circle').value),courseId:track==='Course'?Number(document.getElementById('ops-plan-course').value):null,title:document.getElementById('ops-title').value,track,startsOn:document.getElementById('ops-from').value,endsOn:document.getElementById('ops-to').value,target:Number(document.getElementById('ops-target').value),completed:Number(document.getElementById('ops-completed').value),unit:document.getElementById('ops-unit').value}); Swal.close(); showCenterOperations(); }
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
async function showUnifiedCertificate(kind, id, initialPreviewUrl = null) {
    let previewUrl;
    let closed = false;
    const request = {certificateKind:kind,certificateId:Number(id)};
    Swal.fire({title:'شهادة الإنجاز',width:1050,showConfirmButton:false,showCloseButton:true,
        html:`<div class="operations-actions certificate-preview-actions"><button class="btn btn-success" id="unified-cert-download">تنزيل PDF</button><button class="btn btn-outline-primary" id="unified-cert-print">عرض للطباعة</button></div>
        <div id="unified-cert-loading" role="status" class="certificate-preview-status">${initialPreviewUrl ? 'جاري استكمال المعاينة…' : '<span class="spinner-border text-success"></span> لحظات وتظهر الشهادة…'}</div>
        <img id="unified-cert-preview" ${initialPreviewUrl ? `src="${initialPreviewUrl}"` : ''} alt="شهادة الإنجاز" style="${initialPreviewUrl ? 'display:block' : 'display:none'};width:100%;max-height:65vh;object-fit:contain">`,
        didClose:()=>{closed=true;if(previewUrl)URL.revokeObjectURL(previewUrl);},
        didOpen:popup=>{
            popup.querySelector('#unified-cert-download').onclick=()=>downloadCenterFile({...request,format:'pdf'}).catch(e=>showAlert(e.message,'danger'));
            popup.querySelector('#unified-cert-print').onclick=async()=>{
                const printWindow=window.open('','_blank');
                if(!printWindow){showAlert('يرجى السماح بفتح نافذة الطباعة.','warning');return;}
                try {const pdfUrl=await downloadCenterFile({...request,format:'pdf'},true);
                    printWindow.location.href=pdfUrl;setTimeout(()=>URL.revokeObjectURL(pdfUrl),120000);
                }catch(e){printWindow.close();showAlert(e.message,'danger');}
            };
        }});
    const popup = Swal.getPopup();
    try {
        previewUrl = await downloadCenterFile({...request,format:'png'},true);
        if(closed || Swal.getPopup() !== popup) { URL.revokeObjectURL(previewUrl); return; }
        const img=popup.querySelector('#unified-cert-preview'); img.src=previewUrl; img.style.display='block';
        popup.querySelector('#unified-cert-loading').hidden=true;
    } catch(e) {
        if(!closed && Swal.getPopup() === popup) popup.querySelector('#unified-cert-loading').textContent='تعذر استكمال المعاينة. يمكنك إعادة المحاولة أو تنزيل PDF.';
    }
}
document.addEventListener('DOMContentLoaded',installOperationalTools);
