let parentPortalData=null,parentPortalVersion=0;
async function loadParentPortal(from=null,to=null){
    const container=document.getElementById('parent-children-container');if(!container)return;
    const version=++parentPortalVersion;container.innerHTML='<div class="parent-empty">جاري تحميل متابعة الأبناء…</div>';
    try{
        const query=new URLSearchParams();if(from)query.set('from',from);if(to)query.set('to',to);
        const data=await apiRequest(`/parent/portal?${query}`);if(version!==parentPortalVersion)return;parentPortalData=data;
        container.innerHTML=`<div class="parent-portal-hero"><span class="parent-portal-icon"><i class="fa-solid fa-people-roof"></i></span><div><h3>متابعة أبنائي</h3><p>الحضور والتسميع والحفظ والدورات من سجلات المركز الفعلية.</p><small>مؤشرات الحضور والتسميع تخص الفترة المختارة؛ تقدم الأجزاء يعرض المحفوظ المسجل بالكامل.</small></div></div>
            <div class="parent-portal-filters"><label>من تاريخ<input type="date" id="parent-portal-from" value="${data.from}" max="${data.today}"></label><label>إلى تاريخ<input type="date" id="parent-portal-to" value="${data.to}" max="${data.today}"></label><label>الابن<select id="parent-portal-child" onchange="renderParentPortalChildren()"><option value="">كل الأبناء</option>${data.children.map(c=>`<option value="${c.studentId}">${escapeXml(c.studentName)}</option>`).join('')}</select></label><button class="btn btn-primary" onclick="loadParentPortal(document.getElementById('parent-portal-from').value,document.getElementById('parent-portal-to').value)">عرض المتابعة</button></div>
            <div class="parent-portal-summary">${[['الأبناء',data.summary.childrenCount],['جلسات التسميع',data.summary.totalSessions],['غياب دون عذر',data.summary.absentCount],['غياب بعذر',data.summary.excusedAbsentCount]].map(([label,value])=>`<div><strong>${value}</strong><span>${label}</span></div>`).join('')}</div><div id="parent-portal-children" class="parent-portal-children"></div>`;
        renderParentPortalChildren();
    }catch(e){if(version===parentPortalVersion)container.innerHTML=`<div class="parent-empty"><h3>تعذر تحميل متابعة الأبناء</h3><p>${escapeXml(e.message)}</p><button class="btn btn-primary" onclick="loadParentPortal()">إعادة المحاولة</button></div>`;}
}
function renderParentPortalChildren(){
    const selected=Number(document.getElementById('parent-portal-child')?.value)||null;
    const target=document.getElementById('parent-portal-children');if(!target||!parentPortalData)return;
    const children=parentPortalData.children.filter(c=>!selected||c.studentId===selected);
    if(!children.length){target.innerHTML='<div class="parent-empty"><i class="fa-solid fa-children"></i><h3>لا يوجد أبناء مرتبطون بحسابك</h3><p>تواصل مع إدارة المركز لتدقيق الربط. لا تظهر هنا بيانات أي طالب غير مرتبط بك.</p></div>';return;}
    target.innerHTML=children.map(c=>{
        const progress=Math.min(100,c.completedAjzaaCount/Math.max(1,c.targetAjzaaCount)*100);
        const metric=(label,value)=>`<div><strong>${escapeXml(value)}</strong><span>${label}</span></div>`;
        return `<article class="parent-child-panel"><div class="parent-child-heading"><div><span class="parent-kicker">${escapeXml(c.circleName)}</span><h3>${escapeXml(c.studentName)}</h3><p>المعلم: ${escapeXml(c.teacherName)}</p></div><span class="parent-status ${c.isActive?'':'inactive'}">${c.isActive?'نشط':'معلق'}</span></div>
            <div class="parent-progress-heading"><span>تقدم الحفظ المسجل</span><strong>${c.completedAjzaaCount} / ${c.targetAjzaaCount} جزءاً</strong></div><div class="parent-progress-track"><span style="width:${progress}%"></span></div>
            <div class="parent-child-metrics">${metric('الحضور',c.attendanceRate==null?'لم يرصد':c.attendanceRate+'%')}${metric('جلسات التسميع',c.totalSessions)}${metric('حفظ جديد • صفحة',c.newPages)}${metric('مراجعة • صفحة',c.reviewPages)}${metric('غياب دون عذر',c.absentCount)}${metric('غياب بعذر',c.excusedAbsentCount)}${metric('تأخر',c.lateCount)}${metric('مشاركات المواهب',c.talentsCount)}</div>
            <details class="parent-records" open><summary>آخر جلسات التسميع</summary>${c.recentSessions.map(r=>`<div class="parent-record"><strong>${escapeXml(r.surah)} • ${escapeXml(r.type)}</strong><span>${escapeXml(r.date)} • ${r.pages} صفحة • ${escapeXml(r.assessment)}</span></div>`).join('')||'<p class="parent-muted">لا توجد جلسات مسجلة في هذه الفترة.</p>'}</details>
            <details class="parent-records"><summary>آخر سجلات الحضور</summary>${c.recentAttendance.map(r=>`<div class="parent-record"><strong>${escapeXml(r.status)}</strong><span>${escapeXml(r.date)}</span></div>`).join('')||'<p class="parent-muted">لا يوجد حضور مرصود في هذه الفترة.</p>'}</details>
            <details class="parent-records"><summary>الدورات المسجل بها • ${c.courses.length}</summary>${c.courses.map(r=>`<div class="parent-record"><strong>${escapeXml(r.name)} • ${escapeXml(r.status)}</strong><span>المعلم: ${escapeXml(r.teacherName)} • الدرجة: ${r.grade??'لم ترصد'}</span></div>`).join('')||'<p class="parent-muted">غير مسجل في دورات حالياً.</p>'}</details>
            <div class="parent-child-actions"><button class="btn btn-outline-secondary" onclick="showParentPortalChangeRequest(${c.studentId})">طلب تعديل بيانات الابن</button><button class="btn btn-primary" onclick="showStudent360Modal(${c.studentId})">الملف الشامل</button><button class="btn btn-outline-primary" onclick="downloadStudent360Pdf(${c.studentId})">تنزيل الملف الشامل PDF</button>${c.teacherPhone?`<a class="btn btn-outline-secondary" href="tel:${String(c.teacherPhone).replace(/[^+\d]/g,'')}">التواصل مع المعلم</a>`:''}</div></article>`;
    }).join('');
}
const parentProfileFields={familyContact:'هاتف العائلة',studentMobile:'جوال الطالب',currentAddress:'عنوان السكن',healthStatus:'الحالة الصحية',notes:'ملاحظات'};
async function showParentPortalChangeRequest(studentId){
    const children=parentPortalData?.children||[];if(!children.length){showAlert('لا يوجد أبناء مرتبطون بحسابك.','warning');return;}
    let id=studentId||Number(document.getElementById('parent-portal-child')?.value);
    if(!id&&children.length===1)id=children[0].studentId;
    if(!id){const chosen=await Swal.fire({title:'اختر الابن لتعديل بياناته',input:'select',inputOptions:Object.fromEntries(children.map(c=>[c.studentId,c.studentName])),showCancelButton:true,confirmButtonText:'متابعة',cancelButtonText:'إلغاء'});if(!chosen.isConfirmed)return;id=Number(chosen.value);}
    const child=children.find(c=>c.studentId===id);if(!child)return;
    const profile=child.profile||{};
    const answer=await Swal.fire({title:`طلب تعديل بيانات ${escapeXml(child.studentName)}`,width:650,showCancelButton:true,confirmButtonText:'إرسال للمراجعة',cancelButtonText:'إلغاء',
        html:`<div class="teacher-coverage-form" dir="rtl"><p class="reports-description">يراجع المركز الطلب قبل اعتماد التعديل على بيانات الطالب.</p>${Object.entries(parentProfileFields).map(([key,label])=>`<label>${label}<input id="parent-change-${key}" value="${escapeXml(profile[key]||'')}"></label>`).join('')}</div>`,
        preConfirm:()=>{const changes={};Object.keys(parentProfileFields).forEach(key=>{const value=document.getElementById('parent-change-'+key).value.trim();if(value!==(profile[key]||''))changes[key]=value;});if(!Object.keys(changes).length){Swal.showValidationMessage('غيّر أحد الحقول أولاً.');return false;}return changes;}});
    if(answer.isConfirmed){try{await apiRequest('/profile-update-requests','POST',{studentId:id,requestedByRole:'Parent',requestedByName:getAuthStorage('fullName')||'',changes:answer.value});showAlert('تم إرسال الطلب إلى إدارة المركز للمراجعة.','success');}catch(e){showAlert(e.message,'danger');}}
}
