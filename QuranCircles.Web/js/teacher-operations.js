let teacherAttendanceRows=[];
async function showTeacherAttendance(date){
    try{
        const clock=await apiRequest('/operations/today');const day=date||clock.date;
        await Swal.fire({title:'كشف حضور المعلمين والتغطية البديلة',width:1200,showConfirmButton:false,showCloseButton:true,customClass:{popup:'teacher-attendance-dialog'},
            html:`<div class="teacher-register" dir="rtl"><p class="reports-description">يرصد بدء الحلقة من أول تسميع. بعد 15 دقيقة يظهر التأخر، وبعد انتهاء موعد الحلقة دون نشاط يظهر الغياب تلقائياً. الحلقات التي لا موعد لها لا تُحسب غياباً.</p>
            <div class="reports-fields"><label>من تاريخ<input type="date" id="teacher-register-from" value="${day}"></label><label>إلى تاريخ<input type="date" id="teacher-register-to" value="${day}"></label></div>
            <div class="operations-actions"><button class="btn btn-primary" onclick="refreshTeacherRegister()">تحديث الكشف</button><button class="btn btn-success" onclick="exportTeacherRegister('xlsx')">تنزيل Excel</button><button class="btn btn-outline-danger" onclick="exportTeacherRegister('pdf')">تنزيل PDF</button></div><div id="teacher-register-results" aria-live="polite"></div></div>`,
            didOpen:()=>refreshTeacherRegister()});
    }catch(e){showAlert(e.message,'danger');}
}
async function refreshTeacherRegister(){
    const target=document.getElementById('teacher-register-results');if(!target)return;
    target.innerHTML='<p>جاري تحميل كشف المعلمين…</p>';
    try{
        const from=document.getElementById('teacher-register-from').value,to=document.getElementById('teacher-register-to').value;
        teacherAttendanceRows=await apiRequest(`/operations/teacher-attendance?from=${from}&to=${to}`);
        target.innerHTML=`<div class="table-responsive"><table class="data-table"><thead><tr><th>التاريخ / الحلقة</th><th>المعلم الأصلي</th><th>الحالة</th><th>الموعد / البدء</th><th>البديل</th><th>التغطية</th></tr></thead><tbody>${teacherAttendanceRows.map((r,i)=>`<tr><td>${escapeXml(r.date)}<br><strong>${escapeXml(r.circleName)}</strong></td><td>${escapeXml(r.teacherName)}</td><td><span class="teacher-state state-${r.status}">${escapeXml(r.statusText)}</span>${r.isAutomatic?'<small class="d-block">رصد تلقائي</small>':''}</td><td>${r.scheduledStart||'غير محدد'} / ${r.openedAt||'لم تبدأ'}</td><td>${escapeXml(r.substituteName||'لا يوجد')}<small class="d-block">${escapeXml(r.reason)}</small></td><td>${["Admin","Developer"].includes(currentRole)||(getAuthStorage("taskRole")||"").includes("الجودة")?`<button class="btn btn-sm btn-outline-primary" data-coverage-index="${i}">غياب / تكليف بديل</button>`:""}${r.substituteUserId===Number(currentUserId)?`<button class="btn btn-sm btn-success" data-cover-record="${r.circleId}">رصد التسميع</button>`:""}</td></tr>`).join('')||'<tr><td colspan="6">لا توجد حلقات مجدولة في الفترة.</td></tr>'}</tbody></table></div>`;
        target.querySelectorAll('[data-cover-record]').forEach(button=>button.onclick=()=>startCoverageRecitation(Number(button.dataset.coverRecord)));
        target.querySelectorAll('[data-coverage-index]').forEach(button=>button.onclick=()=>{const r=teacherAttendanceRows[Number(button.dataset.coverageIndex)];showTeacherCoverage(r.circleId,r.circleName,r.date);});
    }catch(e){target.innerHTML=`<p class="reports-error">${escapeXml(e.message)}</p>`;}
}
function exportTeacherRegister(format){
    return downloadCenterFile({format,filter:{kind:'teacher_discipline',from:document.getElementById('teacher-register-from').value,to:document.getElementById('teacher-register-to').value}}).catch(e=>showAlert(e.message,'danger'));
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
    const actions=document.querySelector('#quality-management-section .action-buttons-group');
    if(actions){const button=document.createElement('button');button.className='btn btn-outline-primary';button.textContent='كشف حضور المعلمين والبدلاء';button.onclick=()=>showTeacherAttendance();actions.prepend(button);}
    const teachers=document.getElementById('btn-admin-teachers');
    if(teachers){const link=document.createElement('a');link.className='nav-item admin-only developer-only';link.href='#';link.innerHTML='<i class="fa-solid fa-user-clock"></i><span>حضور المعلمين والبدلاء</span>';link.onclick=e=>{e.preventDefault();showTeacherAttendance();};teachers.after(link);}
});

async function startCoverageRecitation(circleId){
    try{
        const students=(await apiRequest('/students?onlyCircle=true')).filter(s=>s.circleId===circleId&&s.isActive);
        if(!students.length){Swal.showValidationMessage('لا يوجد طلاب نشطون في الحلقة.');return;}
        const answer=await Swal.fire({title:'اختر الطالب للتسميع',input:'select',inputOptions:Object.fromEntries(students.map(s=>[s.id,s.fullName])),showCancelButton:true,confirmButtonText:'فتح سجل التسميع',cancelButtonText:'إلغاء'});
        if(answer.isConfirmed)showSessionFormModal(Number(answer.value));
    }catch(e){showAlert(e.message,'danger');}
}
