const reportGuide = {
    all:['دليل الطلاب والحلقات','قائمة بيانات الطلاب الحالية وأرقام التواصل. لا تتأثر ببحث صفحة إدارة الطلاب.'],
    circle_roster:['طلاب الحلقات والمتابعة القرآنية','كل طالب داخل حلقته، والمعلم، والأجزاء المكتملة، والحفظ والمراجعة والحضور خلال الفترة.'],
    course_roster:['طلاب الدورات والرقابة الأكاديمية','المسجلون في كل دورة مع المعلم والنتيجة وحضور الطالب وغيابه خلال الفترة.'],
    sard_report:['الحفظ والمراجعة والسرد','تفاصيل جلسات التسميع: الطالب والتاريخ والمقدار والدرجة.'],
    combined_chains:['ترشيحات السلاسل المجتمعة','الطلاب المرشحون لاختبارات السلاسل المجتمعة وحالة اختبار كل طالب.'],
    juz_path:['مسار أجزاء الحفظ','الأجزاء المكتملة والمسجلة في ملف الطالب وعدد الأجزاء المتبقية.'],
    khatimun_ijaza:['الخاتمون والتثبيت والإجازة','المسجلون في شؤون الحفاظ وخطط تثبيتهم ورواياتهم.'],
    cumulative_absence:['الغياب التراكمي والإنذارات','طلاب بلغ غيابهم دون عذر الحد الذي تحدده؛ الغياب بعذر يظهر منفصلاً.'],
    teacher_discipline:['حضور المعلمين والتغطية البديلة','كشف كل حلقة ومعلمها الأصلي والبديل والموعد ووقت بدء الجلسة الفعلي.'],
    weekday_absence:['الحضور حسب أيام الأسبوع','ملخص الحضور والتأخر والغياب بعذر ودون عذر حسب اليوم.'],
    exam_results:['الاختبارات والترشيحات','الترشيحات ونتائج الاختبارات ودرجاتها خلال الفترة المختارة.'],
    circle_scorecard:['بطاقة أداء الحلقات','مقارنة الحضور والإنجاز ومتوسط الإتقان بين الحلقات.'],
    intensive_followup:['المتابعة المكثفة','طلاب سجلوا ثلاث جلسات متتالية بدرجات أقل من 70%.'],
    parent_governance:['ربط حسابات أولياء الأمور','الطلاب وحساب ولي الأمر المرتبط وحالة تفعيل الحساب.'],
    whatsapp_directory:['دليل التواصل','أرقام هواتف الطلاب وأولياء الأمور مرتبة حسب الحلقة.'],
    specialized_activities:['الأنشطة والبرامج التخصصية','مشاركات الفتى الواعظ والأصوات الندية وتواريخها وتقييمها.'],
    certificates:['الشهادات الصادرة','شهادات الدورات المعتمدة الصادرة خلال الفترة.'],
    finance:['الحركات المالية','الوارد والصادر والسندات المسجلة خلال الفترة.']
};
let reportPreviewVersion=0;
function installReportCenter() {
    const section=document.getElementById('dynamic-reports-section');
    if(!section || document.getElementById('unified-report-kind'))return;
    const header=section.querySelector('.section-header');
    const panel=document.createElement('div'); panel.className='reports-studio';
    panel.innerHTML=`<div class="reports-intro"><span class="reports-step">1</span><div><h3>ما التقرير الذي تريد استخراجه؟</h3><p>اختر التقرير وحدد نطاقه، ثم اعرض النتائج أو نزّل الملف نفسه بصيغة Excel أو PDF.</p></div></div>
        <div class="reports-fields"><label class="reports-kind">نوع التقرير<select id="unified-report-kind">${Object.entries(reportGuide).map(([key,value])=>`<option value="${key}">${value[0]}</option>`).join('')}</select></label>
        <label>الحلقة<select id="unified-report-circle"><option value="">كل الحلقات</option></select></label>
        <label id="unified-course-field" hidden>الدورة<select id="unified-report-course"><option value="">كل الدورات</option></select></label>
        <label>من تاريخ<input type="date" id="unified-report-from"></label><label>إلى تاريخ<input type="date" id="unified-report-to"></label>
        <label>بحث داخل التقرير<input id="unified-report-search" placeholder="اسم الطالب أو هويته"></label>
        <label id="unified-absence-field" hidden>أقل عدد أيام غياب<input type="number" min="1" max="366" value="3" id="unified-absence-threshold"></label></div>
        <p id="unified-report-description" class="reports-description"></p>
        <label class="reports-filter-choice"><input type="checkbox" id="unified-use-student-filters"> تطبيق فلاتر بيانات الطلاب الإضافية على هذا التقرير</label>
        <div class="operations-actions"><button class="btn btn-primary" onclick="previewUnifiedReport()">عرض النتائج</button><button class="btn btn-success" onclick="exportUnifiedReport('xlsx')">تنزيل Excel</button><button class="btn btn-outline-danger" onclick="exportUnifiedReport('pdf')">تنزيل PDF</button><button class="btn btn-outline-secondary" onclick="resetUnifiedReportFilters()">إعادة الضبط</button></div>
        <div id="unified-report-result" aria-live="polite"><div class="reports-empty"><i class="fa-solid fa-file-lines"></i><h4>تقريرك يبدأ من هنا</h4><p>اختر نوع التقرير ثم اضغط «عرض النتائج».</p></div></div>`;
    const advanced=document.createElement('details'); advanced.id='report-student-details';advanced.className='reports-advanced';
    advanced.innerHTML='<summary>فلاتر بيانات الطلاب الإضافية <span>العمر والحفظ والحالة الصحية والاجتماعية • اختياري</span></summary>';
    [...section.children].filter(el=>el!==header).forEach(el=>advanced.appendChild(el));
    section.append(panel,advanced);
    const oldPreset=advanced.querySelector('#dyn-report-preset-type');
    if(oldPreset)oldPreset.closest('.p-3').hidden=true;
    panel.addEventListener('input',()=>{reportPreviewVersion++;document.getElementById('unified-report-result').innerHTML=''; updateReportGuide();});
    panel.querySelector('#unified-use-student-filters').addEventListener('change',e=>{advanced.open=e.target.checked;});
    updateReportGuide();
}
function updateReportGuide(){
    const kind=document.getElementById('unified-report-kind')?.value||'all';
    const course=document.getElementById('unified-course-field');if(course)course.hidden=kind!=='course_roster';
    const absence=document.getElementById('unified-absence-field');if(absence)absence.hidden=kind!=='cumulative_absence';
    const description=document.getElementById('unified-report-description');if(description)description.textContent=reportGuide[kind]?.[1]||'';
    const scope=document.getElementById('unified-use-student-filters');if(scope){scope.disabled=['finance','teacher_discipline'].includes(kind);if(scope.disabled)scope.checked=false;}
}
function currentReportFilter(kind){
    return {kind:kind||document.getElementById('unified-report-kind')?.value||'all',
        from:document.getElementById('unified-report-from')?.value||null,to:document.getElementById('unified-report-to')?.value||null,
        circleId:Number(document.getElementById('unified-report-circle')?.value)||null,
        courseId:Number(document.getElementById('unified-report-course')?.value)||null,
        search:document.getElementById('unified-report-search')?.value.trim()||null,
        absenceThreshold:Number(document.getElementById('unified-absence-threshold')?.value)||3,
        studentIds:document.getElementById('unified-use-student-filters')?.checked?currentDynamicFilteredStudents.map(s=>s.id):null};
}
async function previewUnifiedReport(){
    const version=++reportPreviewVersion;
    const result=document.getElementById('unified-report-result');if(!result)return;
    result.innerHTML='<div class="reports-empty"><i class="fa-solid fa-spinner fa-spin"></i><p>جاري استخراج السجلات المطابقة…</p></div>';
    try{const data=await apiRequest('/exports/preview','POST',currentReportFilter());if(version!==reportPreviewVersion)return;
        result.innerHTML=`<div class="reports-result-heading"><h4>${escapeXml(data.title)}</h4><p>${escapeXml(data.period)}</p></div>
            ${data.totalRows>200?'<p class="reports-description">المعاينة تعرض أول 200 سجل لسرعة العرض. ملف التنزيل يتضمن جميع النتائج.</p>':''}
            <div class="table-responsive"><table class="data-table"><thead><tr>${data.columns.map(c=>`<th>${escapeXml(c)}</th>`).join('')}</tr></thead><tbody>${data.rows.map(r=>`<tr>${r.map(c=>`<td>${escapeXml(c)}</td>`).join('')}</tr>`).join('')||`<tr><td colspan="${data.columns.length}">لا توجد سجلات مطابقة. جرّب تغيير الفترة أو الحلقة.</td></tr>`}</tbody></table></div>`;
    }catch(e){if(version===reportPreviewVersion)result.innerHTML=`<p class="reports-error">${escapeXml(e.message)}</p>`;}
}
async function exportUnifiedReport(format='xlsx',kind){try{await downloadCenterFile({filter:currentReportFilter(kind),format});}catch(e){showAlert(e.message,'danger');}}
function resetUnifiedReportFilters(){
    reportPreviewVersion++;
    ['unified-report-from','unified-report-to','unified-report-search','unified-report-circle','unified-report-course'].forEach(id=>{const el=document.getElementById(id);if(el)el.value='';});
    document.getElementById('unified-use-student-filters').checked=false;document.getElementById('unified-report-kind').value='all';
    document.getElementById('unified-absence-threshold').value=3;document.getElementById('unified-report-result').innerHTML='';updateReportGuide();
}
