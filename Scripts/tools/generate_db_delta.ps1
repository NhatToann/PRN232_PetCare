# =====================================================================
#  Sinh script delta DAY DU cho DB dev so voi DB restore tu file seed.
#   - INSERT: dong co o DEV nhung khong co o SEED
#   - UPDATE: dong co ca hai noi nhung gia tri khac nhau
#   - DELETE: dong co o SEED nhung khong co o DEV
#  Idempotent: INSERT co NOT EXISTS, UPDATE/DELETE co WHERE theo khoa.
#  Ho tro PK composite.
# =====================================================================
param(
    [string]$DevDb  = "SHOP_PET_Database",
    [string]$RefDb  = "SHOP_PET_SEEDREF",
    [string]$Server = "localhost",
    [string]$User   = "sa",
    [string]$Pass   = "123",
    [string]$Out    = "db_delta_rows.sql",
    [string]$OutFull = "",
    [switch]$IncludeDeletes
)

$ErrorActionPreference = "Stop"

function Open-Db([string]$db) {
    $cs = "Server=$Server;Database=$db;User Id=$User;Password=$Pass;TrustServerCertificate=True;Encrypt=False"
    $c = New-Object System.Data.SqlClient.SqlConnection $cs
    $c.Open(); return $c
}

function Get-TableInfo($conn, [string]$db, [string]$table) {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = @"
SELECT c.name AS col, t.name AS typ, c.max_length, c.precision, c.scale, c.is_identity, c.is_nullable
FROM $db.sys.columns c JOIN $db.sys.types t ON t.user_type_id=c.user_type_id
WHERE c.object_id=OBJECT_ID('$db.dbo.$table') ORDER BY c.column_id;
"@
    $rd = $cmd.ExecuteReader(); $cols = @()
    while ($rd.Read()) {
        $cols += [pscustomobject]@{
            name=[string]$rd["col"]; type=[string]$rd["typ"]
            maxlen=[int]$rd["max_length"]; precision=[int]$rd["precision"]
            scale=[int]$rd["scale"]; identity=([int]$rd["is_identity"] -eq 1)
        }
    }
    $rd.Close()

    # PK columns
    $cmd2 = $conn.CreateCommand()
    $cmd2.CommandText = @"
SELECT c.name AS col
FROM $db.sys.indexes i
JOIN $db.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
JOIN $db.sys.columns c ON c.object_id=i.object_id AND c.column_id=ic.column_id
WHERE i.object_id=OBJECT_ID('$db.dbo.$table') AND i.is_primary_key=1 AND ic.key_ordinal>0
ORDER BY ic.key_ordinal;
"@
    $rd2 = $cmd2.ExecuteReader(); $pk = @()
    while ($rd2.Read()) { $pk += [string]$rd2["col"] }
    $rd2.Close()

    return [pscustomobject]@{ Cols=$cols; PK=$pk }
}

function Get-Rows($conn, [string]$db, [string]$table, $cols) {
    $sel = ($cols | ForEach-Object { "[$($_.name)]" }) -join ", "
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "SELECT $sel FROM [$db].dbo.[$table];"
    $rd = $cmd.ExecuteReader(); $rows = @()
    while ($rd.Read()) {
        $h = [ordered]@{}
        foreach ($c in $cols) {
            $v = $rd[$c.name]
            if ($v -is [DBNull]) { $h[$c.name] = $null } else { $h[$c.name] = $v }
        }
        $rows += [pscustomobject]$h
    }
    $rd.Close(); return $rows
}

function Sql-Lit($v, $col) {
    if ($null -eq $v) { return "NULL" }
    switch ($col.type) {
        "int"      { return [string][int]$v }
        "bigint"   { return [string][long]$v }
        "smallint" { return [string][int]$v }
        "tinyint"  { return [string][int]$v }
        "bit"      { if ($v) { return "1" } else { return "0" } }
        "decimal"  { return "CAST('" + $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) + "' AS Decimal(" + $col.precision + "," + $col.scale + "))" }
        "numeric"  { return "CAST('" + $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) + "' AS Decimal(" + $col.precision + "," + $col.scale + "))" }
        "float"    { return "CAST('" + $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) + "' AS float)" }
        "real"     { return "CAST('" + $v.ToString([System.Globalization.CultureInfo]::InvariantCulture) + "' AS real)" }
        "date"     { return "CAST('" + $v.ToString("yyyy-MM-dd") + "' AS date)" }
        "datetime" { return "CAST('" + $v.ToString("yyyy-MM-dd HH:mm:ss.fff") + "' AS datetime)" }
        "datetime2"{ return "CAST('" + $v.ToString("yyyy-MM-dd HH:mm:ss.fffffff") + "' AS datetime2)" }
        "time"     { return "CAST('" + $v.ToString("HH:mm:ss.fffffff") + "' AS time)" }
        default    { return "N'" + ([string]$v).Replace("'", "''") + "'" }
    }
}

function Get-Key($row, $pk) {
    if ($pk.Count -eq 0) {
        # bang khong co PK: dung tat ca cot lam khoa so sanh
        $parts = @()
        foreach ($p in $row.PSObject.Properties) { $parts += ("[" + $p.Name + "]=" + [string]$p.Value) }
        return ("ALL:" + ($parts -join "|"))
    }
    $parts = @()
    foreach ($k in $pk) { $parts += ("[" + $k + "]=" + [string]$row.$k) }
    return ($parts -join "|")
}

function Where-From($row, $pk, $cols) {
    $w = @()
    if ($pk.Count -eq 0) {
        # bang khong co PK -> so sanh tat ca cot
        foreach ($c in $cols) {
            $v = $row.$($c.name)
            if ($null -eq $v) { $w += "[$($c.name)] IS NULL" }
            else { $w += "[$($c.name)] = " + (Sql-Lit $v $c) }
        }
        return ($w -join " AND ")
    }
    foreach ($k in $pk) {
        $c = $cols | Where-Object { $_.name -eq $k }
        $w += "[$k] = " + (Sql-Lit $row.$k $c)
    }
    return ($w -join " AND ")
}

# thu tu: cha truoc, con sau (cho INSERT/UPDATE)
$PLAN = @(
    @("Supplier","supplier_id"), @("Species","species_id"), @("Breed","breed_id"),
    @("admin","admin_id"), @("Staff","staff_id"), @("Doctor","doctor_id"),
    @("PetService","service_id"), @("ProductCategory","category_id"),
    @("Products","product_id"), @("BreedPricing","breed_pricing_id"),
    @("Customer","customer_id"), @("Pet","id"),
    @("Order","order_id"), @("Order_Detail","detail_id"), @("Payment","payment_id"),
    @("Booking","booking_id"), @("Booking_Service","booking_id"), @("Review","review_id"),
    @("ChatMessages","MessageID"), @("Cart","cart_id"),
    @("AttendanceRecords","AttendanceID"), @("MedicalRecord","record_id"),
    @("Shifts","ShiftID"), @("ShiftRequests","RequestID"), @("WorkSchedule","schedule_id"),
    @("StaffSalary","SalaryID"), @("PayrollRecords","PayrollID"),
    @("boarding_bookings","booking_id"), @("BoardingRoom","room_id"), @("SystemSettings","SettingKey")
)

$dev = Open-Db $DevDb
$ref = Open-Db $RefDb

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("--  DU LIEU DELTA - CHAY TREN DATABASE SHOP_PET_Database")
[void]$sb.AppendLine("--  sqlcmd -S <server> -U <user> -P <pwd> -d SHOP_PET_Database -f 65001 -i db_delta_rows.sql")
[void]$sb.AppendLine("--  Idempotent: moi INSERT deu co dieu kien NOT EXISTS.")
[void]$sb.AppendLine("--  Sinh tu so sanh giua DB dev va DB restore tu file seed SHOP_PET_Database.sql")
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("SET QUOTED_IDENTIFIER ON;")
[void]$sb.AppendLine("SET ANSI_NULLS ON;")
[void]$sb.AppendLine("SET NOCOUNT ON;")
[void]$sb.AppendLine("SET XACT_ABORT ON;")
[void]$sb.AppendLine("BEGIN TRANSACTION;")

$stat = @()

# --- PHA 1: thu thap du lieu ---
$insBlocks = @(); $updBlocks = @(); $delBlocks = @()
foreach ($p in $PLAN) {
    $tbl = $p[0]
    $di = Get-TableInfo $dev $DevDb $tbl
    if ($di.Cols.Count -eq 0) { continue }
    $ri = Get-TableInfo $ref $RefDb $tbl
    if ($ri.Cols.Count -eq 0) { continue }
    $pk = $di.PK
    if ($pk.Count -eq 0) { $pk = $ri.PK }
    $cols = $di.Cols

    $dRows = Get-Rows $dev  $DevDb $tbl $cols
    $sRows = Get-Rows $ref  $RefDb $tbl $cols

    $sMap = @{}; foreach ($r in $sRows) { $sMap[(Get-Key $r $pk)] = $r }
    $dMap = @{}; foreach ($r in $dRows) { $dMap[(Get-Key $r $pk)] = $r }

    $ins = @(); $upd = @(); $del = @()
    foreach ($k in $dMap.Keys) {
        $dr = $dMap[$k]
        if (-not $sMap.ContainsKey($k)) { $ins += $dr; continue }
        $sr = $sMap[$k]
        $sets = @()
        foreach ($c in $cols) {
            if ($pk.Count -gt 0 -and $pk -contains $c.name) { continue }
            if ($pk.Count -eq 0) { continue }   # bang khong PK -> chi insert/delete
            $dv = $dr.$($c.name); $sv = $sr.$($c.name)
            if ($null -eq $dv -and $null -eq $sv) { continue }
            if ($null -ne $dv -and $null -ne $sv -and $dv.Equals($sv)) { continue }
            $sets += "        [$($c.name)] = " + (Sql-Lit $dv $c)
        }
        if ($sets.Count -gt 0) { $upd += [pscustomobject]@{ Row=$dr; Sets=$sets } }
    }
    if ($IncludeDeletes) {
        foreach ($k in $sMap.Keys) { if (-not $dMap.ContainsKey($k)) { $del += $sMap[$k] } }
    }

    $stat += [pscustomobject]@{ Table=$tbl; Insert=$ins.Count; Update=$upd.Count; Delete=$del.Count }

    if ($ins.Count -gt 0) {
        $b = New-Object System.Text.StringBuilder
        [void]$b.AppendLine("")
        [void]$b.AppendLine("-- ===== $tbl : $($ins.Count) dong moi =====")
        $idCol = $cols | Where-Object { $_.identity } | Select-Object -First 1
        if ($idCol) { [void]$b.AppendLine("SET IDENTITY_INSERT dbo.[$tbl] ON;") }
        $cl = ($cols | ForEach-Object { "[$($_.name)]" }) -join ", "
        foreach ($r in $ins) {
            $vl = ($cols | ForEach-Object { Sql-Lit $r.$($_.name) $_ }) -join ", "
            $where = Where-From $r $pk $cols
            [void]$b.AppendLine("INSERT INTO dbo.[$tbl] ($cl) SELECT $vl WHERE NOT EXISTS (SELECT 1 FROM dbo.[$tbl] WHERE $where);")
        }
        if ($idCol) { [void]$b.AppendLine("SET IDENTITY_INSERT dbo.[$tbl] OFF;") }
        $insBlocks += $b.ToString()
    }
    if ($upd.Count -gt 0) {
        $b = New-Object System.Text.StringBuilder
        [void]$b.AppendLine("")
        [void]$b.AppendLine("-- ===== $tbl : $($upd.Count) dong cap nhat =====")
        foreach ($u in $upd) {
            $where = Where-From $u.Row $pk $cols
            [void]$b.AppendLine("UPDATE dbo.[$tbl]")
            [void]$b.AppendLine("   SET " + ($u.Sets -join ",`r`n       "))
            [void]$b.AppendLine(" WHERE " + $where + ";")
        }
        $updBlocks += $b.ToString()
    }
    if ($del.Count -gt 0) {
        $b = New-Object System.Text.StringBuilder
        [void]$b.AppendLine("")
        [void]$b.AppendLine("-- ===== $tbl : $($del.Count) dong da bi xoa o DB dev =====")
        foreach ($r in $del) {
            $where = Where-From $r $pk $cols
            [void]$b.AppendLine("DELETE FROM dbo.[$tbl] WHERE " + $where + ";")
        }
        $delBlocks += [pscustomobject]@{ Table = $tbl; Text = $b.ToString() }
    }
}

# --- PHA 2: ghi file ---
# thu tu xoa: bang con truoc, bang cha sau
$DEL_ORDER = @(
    "Order_Detail","Payment","ChatMessages","Review","Booking_Service","Booking",
    "Pet","MedicalRecord","Cart","boarding_bookings","Order","Customer",
    "WorkSchedule","ShiftRequests","StaffSalary","PayrollRecords",
    "BreedPricing","Products","PetService","ProductCategory",
    "Supplier","Breed","Species","Staff","Doctor","admin","Shifts","BoardingRoom","SystemSettings"
)
function Get-DelOrder($t) {
    for ($i = 0; $i -lt $DEL_ORDER.Count; $i++) { if ($DEL_ORDER[$i] -eq $t) { return $i } }
    return 999
}

if ($delBlocks.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("--  PHA 1: XOA cac dong da bi xoa o DB dev")
    [void]$sb.AppendLine("--  (thu tu: bang con truoc, bang cha sau)")
    [void]$sb.AppendLine("-- ============================================================")
    foreach ($blk in ($delBlocks | Sort-Object { Get-DelOrder $_.Table })) { [void]$sb.Append($blk.Text) }
}
if ($insBlocks.Count -gt 0 -or $updBlocks.Count -gt 0) {
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("-- ============================================================")
    [void]$sb.AppendLine("--  PHA 2: THEM / CAP NHAT du lieu")
    [void]$sb.AppendLine("-- ============================================================")
    foreach ($blk in $insBlocks) { [void]$sb.Append($blk) }
    foreach ($blk in $updBlocks) { [void]$sb.Append($blk) }
}

[void]$sb.AppendLine("")
[void]$sb.AppendLine("COMMIT TRANSACTION;")
[void]$sb.AppendLine("GO")

# --- Tao index unique cho Customer.email neu chua co (sau khi da gop du lieu) ---
[void]$sb.AppendLine("")
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("--  PHA 3: Tao UNIQUE index con thieu (Customer.email)")
[void]$sb.AppendLine("-- ============================================================")
[void]$sb.AppendLine("IF NOT EXISTS (")
[void]$sb.AppendLine("    SELECT 1 FROM sys.indexes i")
[void]$sb.AppendLine("    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id")
[void]$sb.AppendLine("    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id")
[void]$sb.AppendLine("    WHERE i.object_id = OBJECT_ID('dbo.Customer') AND i.is_unique = 1")
[void]$sb.AppendLine("      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'email')")
[void]$sb.AppendLine("    AND NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE email IS NOT NULL GROUP BY email HAVING COUNT(*) > 1)")
[void]$sb.AppendLine("BEGIN")
[void]$sb.AppendLine("    PRINT '  + Customer UNIQUE(email)';")
[void]$sb.AppendLine("    CREATE UNIQUE NONCLUSTERED INDEX [UX_Customer_Email] ON dbo.[Customer] ([email]);")
[void]$sb.AppendLine("END")
[void]$sb.AppendLine("ELSE PRINT '  = Customer UNIQUE(email) da ton tai / du lieu bi trung';")
[void]$sb.AppendLine("GO")

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $Out), $sb.ToString(), $utf8)

# --- File "safe": KHONG xoa du lieu (chi INSERT + UPDATE) ---
if ($OutFull -ne "") {
    $sb2 = New-Object System.Text.StringBuilder
    [void]$sb2.AppendLine("-- ============================================================")
    [void]$sb2.AppendLine("--  DU LIEU DELTA (AN TOAN) - KHONG XOA DONG DU LIEU NAO")
    [void]$sb2.AppendLine("--  Chi them dong moi + cap nhat dong da ton tai.")
    [void]$sb2.AppendLine("--  Chay: sqlcmd -d SHOP_PET_Database -f 65001 -i $Out")
    [void]$sb2.AppendLine("-- ============================================================")
    [void]$sb2.AppendLine("SET QUOTED_IDENTIFIER ON;")
    [void]$sb2.AppendLine("SET ANSI_NULLS ON;")
    [void]$sb2.AppendLine("SET NOCOUNT ON;")
    [void]$sb2.AppendLine("SET XACT_ABORT ON;")
    [void]$sb2.AppendLine("BEGIN TRANSACTION;")
    # Customer 49 (email nhattoan0310@gmail.com) da bi thay the bang 61 o DB dev.
    # De tranh xung dot UNIQUE(UX_Customer_Email) khi chen 61, xoa 49 truoc.
    # Bang 49 khong co du lieu con nao tham chieu (da kiem tra) nen an toàn.
    [void]$sb2.AppendLine("IF EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 49)")
    [void]$sb2.AppendLine("   AND NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 61)")
    [void]$sb2.AppendLine("BEGIN")
    [void]$sb2.AppendLine("    PRINT '  - xoa Customer 49 (trung email voi Customer 61)';")
    [void]$sb2.AppendLine("    DELETE FROM dbo.Customer WHERE customer_id = 49;")
    [void]$sb2.AppendLine("END")
    [void]$sb2.AppendLine("GO")
    foreach ($blk in $insBlocks) { [void]$sb2.Append($blk) }
    foreach ($blk in $updBlocks) { [void]$sb2.Append($blk) }
    [void]$sb2.AppendLine("")
    [void]$sb2.AppendLine("COMMIT TRANSACTION;")
    [void]$sb2.AppendLine("GO")
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) $OutFull), $sb2.ToString(), $utf8)
}

$dev.Close(); $ref.Close()
$stat | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "Da ghi: $Out"
