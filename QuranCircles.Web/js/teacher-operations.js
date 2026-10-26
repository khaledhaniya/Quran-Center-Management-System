let teacherAttendanceRows=[];
function installTeacherRegisterPage(){
    if(document.getElementById('teacher-register-section'))return;
    const main=document.querySelector('main.main-content');if(!main)return;
    const section=document.createElement('section');section.id='teacher-register-section';section.className='content-section hidden';
    section.innerHTML=`<div class="section-header"><div><h2>حضور المعلمين والبدلاء</h2><p>كشف التشغيل لكل يوم • المعلم الأصلي والتغطية الفعلية</p></div><div class="operations-actions"><button class="btn btn-success" onclick="exportTeacherRegister('xlsx')">تنزيل Excel</button><button class="btn btn-outline-danger" onclick="exportTeacherRegister('pdf')">تنزيل PDF</button></div></div>
        <div class="reports-studio teacher-register"><p class="reports-description">اختر فترة تصل إلى 92 يوماً. يظهر كل يوم في سطر مستقل مع حالة الغياب والبديل المسند له.</p>
        <div class="reports-fields"><label>من تاريخ<input type="date" id="teacher-register-from"></label><label>إلى تاريخ<input type="date" id="teacher-register-date"></label>
        <label>الحلقة<select id="teacher-register-circle"><option value="">كل الحلقات</option></select></label>
        <label>المعلم أو الحلقة<input type="search" id="teacher-register-search" placeholder="اسم المعلم الأصلي أو البديل أو الحلقة"></label></div>
        <div class="operations-actions"><button class="btn btn-primary" onclick="refreshTeacherRegister()">عرض الكشف</button><button class="btn btn-outline-secondary" onclick="resetTeacherRegister()">كشف اليوم بالكامل</button></div>
        <div id="teacher-register-day" class="teacher-register-day"></div><div id="teacher-register-summary" class="teacher-register-summary"></div><div id="teacher-register-results" aria-live="polite"></div></div>`;
    main.append(section);
}
function teacherRegisterFilter(){return {kind:'teacher_discipline',from:document.getElementById('teacher-register-from').value,to:document.getElementById('teacher-register-date').value,circleId:Number(document.getElementById('teacher-register-circle').value)||null,search:document.getElementById('teacher-register-search').value.trim()||null};}
async function loadTeacherRegisterPage(date){
    installTeacherRegisterPage();
    try{
        const [clock,circles]=await Promise.all([apiRequest('/operations/today'),apiRequest('/circles')]);
        const picker=document.getElementById('teacher-register-date');
        picker.max=clock.date;if(date||!picker.value)picker.value=date||clock.date;
        const fromPicker=document.getElementById('teacher-register-from');
        fromPicker.max=picker.value;
        if(date||!fromPicker.value){const start=new Date(`${picker.value}T12:00:00`);start.setDate(start.getDate()-30);fromPicker.value=date||start.toISOString().slice(0,10);}
        const select=document.getElementById('teacher-register-circle'),value=select.value;
        select.innerHTML='<option value="">كل الحلقات</option>'+circles.map(c=>`<option value="${c.id}">${escapeXml(c.name)}</option>`).join('');select.value=value;
        await refreshTeacherRegister();
    }catch(e){showAlert(e.message,'danger');}
}
function showTeacherAttendance(date){
    installTeacherRegisterPage();
    if(date){document.getElementById('teacher-register-date').value=date;document.getElementById('teacher-register-from').value=date;}
    if(location.hash==='#teacher-register')return loadTeacherRegisterPage(date);
    location.hash='#teacher-register';
}
async function resetTeacherRegister(){
    ['teacher-register-circle','teacher-register-search'].forEach(id=>document.getElementById(id).value='');
    const clock=await apiRequest('/operations/today');return loadTeacherRegisterPage(clock.date);
}
let teacherRegisterVersion=0;
function teacherAbsenceLabel(row){
    if(row.status==='Absent')return 'غائب';
    if(row.status==='Pending'||row.status==='LatePending')return 'قيد المتابعة';
    if(row.status==='Suspended')return 'الحلقة معلقة';
    if(row.status==='Unscheduled')return 'دون موعد';
    return 'مش غايب';
}
async function refreshTeacherRegister(){
    const target=document.getElementById('teacher-register-results');if(!target)return;
    const version=++teacherRegisterVersion;
    target.innerHTML='<p>جاري تحميل كشف المعلمين…</p>';
    try{
        const filter=teacherRegisterFilter();
        if(filter.from>filter.to || (new Date(filter.to)-new Date(filter.from))/86400000>92)throw new Error('حدد فترة صحيحة لا تتجاوز 92 يوماً.');
        const query=new URLSearchParams(Object.entries(filter).filter(([k,v])=>k!=='kind'&&v!==null));
        const rows=await apiRequest(`/operations/teacher-attendance?${query}`);if(version!==teacherRegisterVersion)return;teacherAttendanceRows=rows;
        document.getElementById('teacher-register-day').innerHTML=`<i class="fa-regular fa-calendar-check"></i><span>كشف الفترة <strong>${escapeXml(filter.from)}</strong> إلى <strong>${escapeXml(filter.to)}</strong></span>`;
        document.getElementById('teacher-register-summary').innerHTML=[['الحلقات في الكشف',rows.length],['الغياب المسجل',rows.filter(r=>r.status==='Absent').length],['أسباب الغياب الموثقة',rows.filter(r=>r.status==='Absent'&&r.reason).length],['مش غايب',rows.filter(r=>teacherAbsenceLabel(r)==='مش غايب').length]].map(([label,count])=>`<div><strong>${count}</strong><span>${label}</span></div>`).join('');
        target.innerHTML=`<div class="table-responsive"><table class="data-table"><thead><tr><th>اليوم والتاريخ</th><th>الحلقة</th><th>المعلم الأصلي</th><th>وقت الحلقة</th><th>البدء / الإغلاق</th><th>التأخير</th><th>الغياب</th><th>العذر</th><th>المعلم البديل</th><th>الإجراء</th></tr></thead><tbody>${teacherAttendanceRows.map((r,i)=>`<tr><td><strong>${escapeXml(new Intl.DateTimeFormat('ar',{weekday:'long'}).format(new Date(`${r.date}T12:00:00`)))}</strong><br>${escapeXml(r.date)}</td><td><strong>${escapeXml(r.circleName)}</strong></td><td>${escapeXml(r.teacherName)}</td><td>${r.scheduledStart?`${escapeXml(r.scheduledStart)} - ${escapeXml(r.scheduledEnd||'')}`:'غير محدد'}</td><td>${escapeXml(r.openedAt||'لم تبدأ')} / ${escapeXml(r.closedAt||'لم تغلق')}</td><td>${r.lateMinutes==null?'—':`${r.lateMinutes} دقيقة`}</td><td><span class="teacher-state state-${r.status}">${escapeXml(teacherAbsenceLabel(r))}</span><small class="d-block">${escapeXml(r.statusText)}</small></td><td>${escapeXml(r.status==='Absent'?(r.reason||'لم يذكر عذر'):'—')}</td><td>${escapeXml(r.substituteName||'لا يوجد')}</td><td>${["Admin","Developer"].includes(currentRole)||(currentRole==='Teacher'&&teacherCan('quality'))?`<button class="btn btn-sm btn-outline-primary" data-coverage-index="${i}">تسجيل غياب / بديل</button>`:""}${r.substituteUserId===Number(currentUserId)?`<button class="btn btn-sm btn-success" data-cover-record="${r.circleId}">رصد التسميع</button>`:""}</td></tr>`).join('')||'<tr><td colspan="10">لا توجد حلقات في هذه الفترة.</td></tr>'}</tbody></table></div>`;
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
            <p class="teacher-coverage-date">تاريخ الكشف: <strong>${escapeXml(date||clock.date)}</strong></p>
            <label>الحساب المكلّف بالتغطية<select id="coverage-user"><option value="">غياب دون معلم بديل / إلغاء التكليف</option>${candidates.map(u=>`<option value="${u.id}">${escapeXml(u.fullName)}</option>`).join('')}</select></label>
            <label>العذر أو سبب الغياب<textarea id="coverage-reason" rows="2" placeholder="اكتب العذر، أو اكتب: بدون عذر"></textarea></label></div>`,
            preConfirm:()=>{const reason=document.getElementById('coverage-reason').value.trim();if(!reason){Swal.showValidationMessage('سبب الغياب مطلوب.');return false;}return {date:date||clock.date,substituteUserId:Number(document.getElementById('coverage-user').value)||null,reason};}});
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
