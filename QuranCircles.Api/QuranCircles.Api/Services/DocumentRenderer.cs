using ClosedXML.Excel;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using QuestPDF.Drawing;

namespace QuranCircles.Api.Services;

public record ReportTable(string Title, string[] Columns, List<string[]> Rows, string Period);
public record CertificateData(string Center, string Student, string Course, string Code, string Date, string Grade,
    string Signatory, string Instructor = "", string InstructorTitle = "");

public static class DocumentRenderer
{
    private static readonly object Gate = new();
    private static bool ready;
    public static void Initialize()
    {
        lock (Gate)
        {
            if (ready) return;
            // Educational Quran centre: Community licence. See THIRD_PARTY_NOTICES.md.
            QuestPDF.Settings.License = LicenseType.Community;
            using var font = File.OpenRead(Path.Combine(AppContext.BaseDirectory, "wwwroot", "assets", "fonts", "Amiri-Regular.ttf"));
            FontManager.RegisterFontFromStream(font); ready = true;
        }
    }

    public static byte[] Excel(ReportTable report)
    {
        using var book = new XLWorkbook();
        var sheet = book.Worksheets.Add("التقرير"); sheet.RightToLeft = true;
        sheet.Style.Font.FontName = "Arial"; sheet.Style.Font.FontSize = 12;
        sheet.Cell(1, 1).Value = report.Title; sheet.Range(1, 1, 1, report.Columns.Length).Merge();
        sheet.Row(1).Height = 32; sheet.Row(1).Style.Fill.BackgroundColor = XLColor.FromHtml("#0D5C3A");
        sheet.Row(1).Style.Font.FontColor = XLColor.White; sheet.Row(1).Style.Font.Bold = true;
        sheet.Cell(2, 1).Value = report.Period; sheet.Range(2, 1, 2, report.Columns.Length).Merge();
        for (var c = 0; c < report.Columns.Length; c++) sheet.Cell(4, c + 1).Value = report.Columns[c];
        for (var r = 0; r < report.Rows.Count; r++)
            for (var c = 0; c < report.Columns.Length; c++)
                sheet.Cell(r + 5, c + 1).Value = report.Rows[r][c]; // Strings, never executable formulas.
        var range = sheet.Range(4, 1, Math.Max(4, report.Rows.Count + 4), report.Columns.Length);
        range.Style.Alignment.WrapText = true; range.Style.Alignment.Vertical = XLAlignmentVerticalValues.Center;
        if (report.Rows.Count > 0) range.CreateTable().Theme = XLTableTheme.TableStyleMedium4;
        sheet.Columns(1, report.Columns.Length).Width = 25;
        sheet.SheetView.FreezeRows(4); sheet.PageSetup.PageOrientation = XLPageOrientation.Landscape;
        sheet.PageSetup.FitToPages(1, 0); sheet.PageSetup.SetRowsToRepeatAtTop(1, 4);
        using var output = new MemoryStream(); book.SaveAs(output); return output.ToArray();
    }

    public static byte[] Pdf(ReportTable report)
    {
        Initialize();
        return Document.Create(doc => doc.Page(page => {
            page.Size(PageSizes.A4.Landscape()); page.Margin(25); page.ContentFromRightToLeft();
            page.DefaultTextStyle(x => x.FontFamily("Amiri").FontSize(11));
            page.Header().PaddingBottom(12).Column(col => {
                col.Item().Text(report.Title).FontSize(22).FontColor("#0D5C3A");
                col.Item().Text(report.Period).FontSize(10);
            });
            page.Content().Table(table => {
                table.ColumnsDefinition(columns => { foreach (var _ in report.Columns) columns.RelativeColumn(); });
                table.Header(header => { foreach (var column in report.Columns) header.Cell().Background("#0D5C3A").Padding(5).Text(column).FontColor(Colors.White); });
                for (var i = 0; i < report.Rows.Count; i++)
                    foreach (var cell in report.Rows[i]) table.Cell().Background(i % 2 == 0 ? "#F0F7F4" : "#FFFFFF").BorderBottom(.4f).BorderColor("#DCE5DF").Padding(5).Text(cell);
            });
            page.Footer().AlignCenter().Text(t => { t.Span("صفحة "); t.CurrentPageNumber(); t.Span(" / "); t.TotalPages(); });
        })).GeneratePdf();
    }

    public static IDocument Certificate(CertificateData data)
    {
        Initialize();
        var logo = Path.Combine(AppContext.BaseDirectory, "wwwroot", "assets", "logo.png");
        return Document.Create(doc => doc.Page(page => {
            page.Size(PageSizes.A4.Landscape()); page.Margin(18); page.ContentFromRightToLeft();
            page.DefaultTextStyle(t => t.FontFamily("Amiri").FontSize(17).FontColor("#153F32"));
            page.Content().Border(3).BorderColor("#B99550").Padding(8).Border(1).BorderColor("#D8C59C").Padding(16).Column(col => {
                col.Spacing(7);
                if (File.Exists(logo)) col.Item().AlignCenter().Height(110).Image(logo).FitArea();
                col.Item().AlignCenter().Text(data.Center).FontSize(21);
                col.Item().AlignCenter().Text("شهادة إنجاز وتقدير").FontSize(34).FontColor("#9D752F");
                col.Item().AlignCenter().Text("تشهد إدارة المركز بأن الطالب").FontSize(17);
                col.Item().AlignCenter().Text(data.Student).FontSize(30);
                col.Item().AlignCenter().Text($"قد أتم بنجاح: {data.Course}").FontSize(20);
                col.Item().AlignCenter().Text($"النتيجة: {data.Grade}    •    التاريخ: {data.Date}").FontSize(15);
                col.Item().PaddingTop(24).Row(row => {
                    row.RelativeItem().Column(right => {
                        right.Item().AlignCenter().Text("أمير المركز").FontSize(14).FontColor("#9D752F");
                        right.Item().AlignCenter().Text(data.Signatory).FontSize(18);
                    });
                    row.RelativeItem().AlignCenter().AlignMiddle().ContentFromLeftToRight().Text(data.Code).FontSize(11);
                    row.RelativeItem().Column(left => {
                        if (!string.IsNullOrWhiteSpace(data.Instructor)) {
                            left.Item().AlignCenter().Text(data.InstructorTitle).FontSize(14).FontColor("#9D752F");
                            left.Item().AlignCenter().Text(data.Instructor).FontSize(18);
                        }
                    });
                });
            });
        }));
    }
}
