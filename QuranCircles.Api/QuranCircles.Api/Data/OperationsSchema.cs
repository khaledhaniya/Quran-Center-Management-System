#pragma warning disable EF1002 // DDL identifiers and types below are fixed compile-time allowlists, never request values.
using Microsoft.EntityFrameworkCore;

namespace QuranCircles.Api.Data;

public static class OperationsSchema
{
    // Generate the new tables from the same EF model used for fresh installations.
    // Existing operational rows are never seeded, replaced or deleted here.
    public static void Ensure(AppDbContext db)
    {
        foreach (var (column, type) in new[] {
            ("RecordedCircleId", "int"), ("RecordedByUserId", "int"),
            ("Pages", "float"), ("Score", "float"), ("RecordedAt", "datetime2") })
        {
            if (db.Database.IsSqlServer())
                db.Database.ExecuteSqlRaw($"IF COL_LENGTH('Sessions', '{column}') IS NULL ALTER TABLE Sessions ADD [{column}] {type} NULL");
            else if (db.Database.IsNpgsql())
                db.Database.ExecuteSqlRaw($"ALTER TABLE \"Sessions\" ADD COLUMN IF NOT EXISTS \"{column}\" {(type == "datetime2" ? "timestamp with time zone" : type == "float" ? "double precision" : "integer")} NULL");
            else if (db.Database.SqlQueryRaw<int>($"SELECT COUNT(*) AS Value FROM pragma_table_info('Sessions') WHERE name = '{column}'").Single() == 0)
                db.Database.ExecuteSqlRaw($"ALTER TABLE Sessions ADD COLUMN {column} {(type == "datetime2" ? "TEXT" : type == "float" ? "REAL" : "INTEGER")} NULL");
        }
        // QualityVisits used to be created only by the SQLite-specific migration.
        // SQL Server installations also need it before the quality overview is queried.
        var tables = new[] { "CirclePlans", "CircleSchedules", "CircleDays", "QualityVisits" };
        var script = db.Database.GenerateCreateScript();
        foreach (var table in tables)
        {
            var quoted = db.Database.IsSqlServer() ? $"[{table}]" : $"\"{table}\"";
            var pattern = $@"CREATE TABLE {System.Text.RegularExpressions.Regex.Escape(quoted)}\s*\([\s\S]*?\);";
            var sql = System.Text.RegularExpressions.Regex.Match(script, pattern).Value;
            if (sql.Length == 0) throw new InvalidOperationException($"Missing schema for {table}");
            if (db.Database.IsSqlServer()) sql = $"IF OBJECT_ID(N'{table}', N'U') IS NULL BEGIN {sql} END";
            else sql = sql.Replace("CREATE TABLE ", "CREATE TABLE IF NOT EXISTS ");
            db.Database.ExecuteSqlRaw(sql);
        }
        if (db.Database.IsSqlServer())
            db.Database.ExecuteSqlRaw("IF COL_LENGTH('CirclePlans', 'CourseId') IS NULL ALTER TABLE CirclePlans ADD CourseId int NULL");
        else if (db.Database.IsNpgsql())
            db.Database.ExecuteSqlRaw("ALTER TABLE \"CirclePlans\" ADD COLUMN IF NOT EXISTS \"CourseId\" integer NULL");
        else if (db.Database.SqlQueryRaw<int>("SELECT COUNT(*) AS Value FROM pragma_table_info('CirclePlans') WHERE name = 'CourseId'").Single() == 0)
            db.Database.ExecuteSqlRaw("ALTER TABLE CirclePlans ADD COLUMN CourseId INTEGER NULL");
        foreach (var (table, index, columns) in new[] {
            ("CircleSchedules", "IX_CircleSchedules_CircleId", "CircleId"),
            ("CircleDays", "IX_CircleDays_CircleId_Date", "CircleId,Date") })
        {
            string Q(string value) => db.Database.IsSqlServer() ? $"[{value}]" : $"\"{value}\"";
            var sql = $"CREATE UNIQUE INDEX {Q(index)} ON {Q(table)} ({string.Join(',', columns.Split(',').Select(Q))})";
            sql = db.Database.IsSqlServer()
                ? $"IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = '{index}' AND object_id = OBJECT_ID('{table}')) {sql}"
                : sql.Replace("CREATE UNIQUE INDEX", "CREATE UNIQUE INDEX IF NOT EXISTS");
            db.Database.ExecuteSqlRaw(sql);
        }
    }
}
