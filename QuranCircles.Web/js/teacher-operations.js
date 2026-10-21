let teacherAttendanceRows=[];
function installTeacherRegisterPage(){
    if(document.getElementById('teacher-register-section'))return;
    const quality=document.getElementById('quality-management-section');if(!quality)return;
    const overview=document.createElement('div');overview.id='quality-overview-panel';
    while(quality.firstChild)overview.appendChild(quality.firstChild);
    quality.appendChild(overview);
    const tabs=document.createElement('nav');tabs.className='quality-register-tabs';tabs.setAttribute('aria-label','أقسام ملف الجودة');
    tabs.innerHTML='<a id="quality-overview-tab" href="#quality-management"><i class="fa-solid fa-award"></i> مؤشرات الجودة والرقابة</a><a id="quality-attendance-tab" href="#teacher-register"><i class="fa-solid fa-user-clock"></i> كشف حضور المعلمين والبدلاء</a>';
    quality.prepend(tabs);
    const section=document.createElement('section');section.id='teacher-register-section';section.className='hidden';
    section.innerHTML=`<div class="section-header"><div><h2>حضور المعلمين والبدلاء</h2><p>كشف التشغيل اليومي لكل حلقة • المعلم الأصلي والتغطية الفعلية</p></div><div class="operations-actions"><button class="btn btn-success" onclick="exportTeacherRegister('xlsx')">تنزيل Excel</button><button class="btn btn-outline-danger" onclick="exportTeacherRegister('pdf')">تنزيل PDF</button></div></div>
        <div class="reports-studio teacher-register"><p class="reports-description">يرصد بدء الحلقة من أول تسميع. يظهر التأخر بعد 15 دقيقة، والغياب بعد انتهاء موعد الحلقة دون نشاط. الموعد غير المحدد لا يُحسب غياباً.</p>
        <div class="reports-fields"><label>من تاريخ<input type="date" id="teacher-register-from"></label><label>إلى تاريخ<input type="date" id="teacher-register-to"></label>
        <label>الحلقة<select id="teacher-register-circle"><option value="">كل الحلقات</option></select></label>
        <label>الحالة<select id="teacher-register-status"><option value="">كل الحالات</option><option value="Present">حاضر</option><option value="Late">حاضر متأخر</option><option value="Absent">غائب</option><option value="LatePending">متأخر ولم تبدأ</option><option value="Pending">بانتظار البدء</option><option value="Suspended">معلقة</option><option value="Unscheduled">دون موعد</option></select></label>
        <label>المعلم أو الحلقة<input type="search" id="teacher-register-search" placeholder="اسم المعلم الأصلي أو البديل أو الحلقة"></label></div>
        <div class="operations-actions"><button class="btn btn-primary" onclick="refreshTeacherRegister()">عرض الكشف</button><button class="btn btn-outline-secondary" onclick="resetTeacherRegister()">كشف اليوم بالكامل</button></div>
        <div id="teacher-register-summary" class="teacher-register-summary"></div><div id="teacher-register-results" aria-live="polite"></div></div>`;
    quality.append(section);
}
function showQualityRegisterPanel(attendance){
    installTeacherRegisterPage();
    document.getElementById('quality-overview-panel')?.classList.toggle('hidden',attendance);
    document.getElementById('teacher-register-section')?.classList.toggle('hidden',!attendance);
    document.getElementById('quality-overview-tab')?.classList.toggle('active',!attendance);
    document.getElementById('quality-attendance-tab')?.classList.toggle('active',attendance);
}
function teacherRegisterFilter(){return {kind:'teacher_discipline',from:document.getElementById('teacher-register-from').value,to:document.getElementById('teacher-register-to').value,circleId:Number(document.getElementById('teacher-register-circle').value)||null,status:document.getElementById('teacher-register-status').value||null,search:document.getElementById('teacher-register-search').value.trim()||null};}
async function loadTeacherRegisterPage(date){
    installTeacherRegisterPage();
    try{
        const [clock,circles]=await Promise.all([apiRequest('/operations/today'),apiRequest('/circles')]);
        const from=document.getElementById('teacher-register-from'),to=document.getElementById('teacher-register-to');
        if(date||!from.value)from.value=date||clock.date;if(date||!to.value)to.value=date||clock.date;
        const select=document.getElementById('teacher-register-circle'),value=select.value;
        select.innerHTML='<option value="">كل الحلقات</option>'+circles.map(c=>`<option value="${c.id}">${escapeXml(c.name)}</option>`).join('');select.value=value;
        await refreshTeacherRegister();
    }catch(e){showAlert(e.message,'danger');}
}
function showTeacherAttendance(date){
    installTeacherRegisterPage();
    if(date){document.getElementById('teacher-register-from').value=date;document.getElementById('teacher-register-to').value=date;}
    if(location.hash==='#teacher-register')return loadTeacherRegisterPage(date);
    location.hash='#teacher-register';
}
async function resetTeacherRegister(){
    ['teacher-register-circle','teacher-register-status','teacher-register-search'].forEach(id=>document.getElementById(id).value='');
    const clock=await apiRequest('/operations/today');return loadTeacherRegisterPage(clock.date);
}
let teacherRegisterVersion=0;
async function refreshTeacherRegister(){
    const target=document.getElementById('teacher-register-results');if(!target)return;
    const version=++teacherRegisterVersion;
    target.innerHTML='<p>جاري تحميل كشف المعلمين…</p>';
    try{
        const filter=teacherRegisterFilter();
        const query=new URLSearchParams(Object.entries(filter).filter(([k,v])=>k!=='kind'&&v!==null));
        const rows=await apiRequest(`/operations/teacher-attendance?${query}`);if(version!==teacherRegisterVersion)return;teacherAttendanceRows=rows;
        document.getElementById('teacher-register-summary').innerHTML=[['السجلات',rows.length],['حاضر',rows.filter(r=>['Present','Late'].includes(r.status)).length],['غائب',rows.filter(r=>r.status==='Absent').length],['تغطية بديلة',rows.filter(r=>r.substituteUserId).length]].map(([label,count])=>`<div><strong>${count}</strong><span>${label}</span></div>`).join('');
        target.innerHTML=`<div class="table-responsive"><table class="data-table"><thead><tr><th>التاريخ / الحلقة</th><th>المعلم الأصلي</th><th>الحالة</th><th>الموعد</th><th>بدء الحلقة</th><th>إغلاق الحلقة</th><th>دقائق التأخر</th><th>البديل / السبب</th><th>الإجراء</th></tr></thead><tbody>${teacherAttendanceRows.map((r,i)=>`<tr><td>${escapeXml(r.date)}<br><strong>${escapeXml(r.circleName)}</strong></td><td>${escapeXml(r.teacherName)}</td><td><span class="teacher-state state-${r.status}">${escapeXml(r.statusText)}</span>${r.isAutomatic?'<small class="d-block">رصد تلقائي</small>':''}</td><td>${escapeXml(r.scheduledStart||'غير محدد')}</td><td>${escapeXml(r.openedAt||'لم تبدأ')}</td><td>${escapeXml(r.closedAt||'لم تغلق')}</td><td>${r.lateMinutes??'—'}</td><td>${escapeXml(r.substituteName||'لا يوجد')}<small class="d-block">${escapeXml(r.reason||'')}</small></td><td>${["Admin","Developer"].includes(currentRole)||(currentRole==='Teacher'&&teacherCan('quality'))?`<button class="btn btn-sm btn-outline-primary" data-coverage-index="${i}">غياب / تكليف بديل</button>`:""}${r.substituteUserId===Number(currentUserId)?`<button class="btn btn-sm btn-success" data-cover-record="${r.circleId}">رصد التسميع</button>`:""}</td></tr>`).join('')||'<tr><td colspan="9">لا توجد حلقات مجدولة في الفترة.</td></tr>'}</tbody></table></div>`;
        target.querySelectorAll('[data-cover-record]').forEach(button=>button.onclick=()=>startCoverageRecitation(Number(button.dataset.coverRecord)));
        target.querySelectorAll('[data-coverage-index]').forEach(button=>button.onclick=()=>{const r=teacherAttendanceRows[Number(button.dataset.coverageIndex)];showTeacherCoverage(r.circleId,r.circleName,r.date);});
    }catch(e){target.innerHTML=`<p class="reports-error">${escapeXml(e.message)}</p>`;}
}
function exportTeacherRegister(format){
    return downloadCenterFile({format,filter:teacherRegisterFilter()}).catch(e=>showAlert(e.message,'danger'));
}
async function showTeacherCoverage(circleId,circleName,date){
    try{
        const [candidates,clock]=await Promise.all([apiRequest(`/operations/substitutes?circleId=${circleId}`),apiRequest('/operations/today')]);
        const result=await Swal.fire({title:`غياب وتغطية • ${escapeXml(circleName)}`,width:620,showCancelButton:true,confirmButtonText:'حفظ الغياب والتكليف',cancelButtonText:'إلغاء',customClass:{popup:'teacher-coverage-dialog'},
            html:`<div class="teacher-coverage-form" dir="rtl"><p class="reports-description">يسجل المعلم الأصلي غائباً لهذا اليوم. الحساب الذي تختاره هو المخوّل بالتسميع بدلاً عنه، ويظهر اسمه في كشف الحضور وسجل التدقيق.</p>
            <label>التاريخ<input type="date" id="coverage-date" value="${date||clock.date}" max="${clock.date}"></label>
            <label>الحساب المكلّف بالتغطية<select id="coverage-user"><option value="">غياب دون معلم بديل / إلغاء التكليف</option>${candidates.map(u=>`<option value="${u.id}">${escapeXml(u.fullName)}</option>`).join('')}</select></label>
            <label>سبب الغياب أو الإجازة<textarea id="coverage-reason" rows="2" placeholder="سبب الغياب وتفاصيل التكليف"></textarea></label></div>`,
            preConfirm:()=>{const reason=document.getElementById('coverage-reason').value.trim();if(!reason){Swal.showValidationMessage('سبب الغياب مطلوب.');return false;}return {date:document.getElementById('coverage-date').value,substituteUserId:Number(document.getElementById('coverage-user').value)||null,reason};}});
        if(result.isConfirmed){await apiRequest(`/operations/coverage/${circleId}`,'POST',result.value);showTeacherAttendance(result.value.date);}
    }catch(e){showAlert(e.message,'danger');}
}
function showQualityStudents(kind,id){
    const rows=kind==='course'?cachedQualityOverview?.courses:cachedQualityOverview?.circles;
    const row=rows?.find(r=>r.id===id);if(!row)return;
    const students=row.students||[];
    Swal.fire({title:`طلاب ${escapeXml(row.name)}`,width:960,showConfirmButton:false,showCloseButton:true,
        html:`<p class="reports-description">المسجلون فعلياً • ${students.length} طالباً</p><div class="table-responsive"><table class="data-table"><thead><tr><th>الطالب</th><th>الحضور</th><th>الغياب</th><th>${kind==='course'?'الدرجة':'جلسات التسميع'}</th></tr></thead><tbody>${students.map(s=>`<tr><td>${escapeXml(s.studentName||s.fullName)}</td><td>${s.presentCount||0}</td><td>${s.absentCount||0}</td><td>${kind==='course'?(s.grade??'لم ترصد'):(s.totalRecitations||0)}</td></tr>`).join('')||'<tr><td colspan="4">لا يوجد طلاب مسجلون.</td></tr>'}</tbody></table></div>`});
}
document.addEventListener('DOMContentLoaded',()=>{
    installTeacherRegisterPage();
});

async function startCoverageRecitation(circleId){
    try{
        const students=(await apiRequest('/students?onlyCircle=true')).filter(s=>s.circleId===circleId&&s.isActive);
        if(!students.length){Swal.showValidationMessage('لا يوجد طلاب نشطون في الحلقة.');return;}
        const answer=await Swal.fire({title:'اختر الطالب للتسميع',input:'select',inputOptions:Object.fromEntries(students.map(s=>[s.id,s.fullName])),showCancelButton:true,confirmButtonText:'فتح سجل التسميع',cancelButtonText:'إلغاء'});
        if(answer.isConfirmed)showSessionFormModal(Number(answer.value));
    }catch(e){showAlert(e.message,'danger');}
}
