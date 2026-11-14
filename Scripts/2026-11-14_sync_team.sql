/* =====================================================================
   2026-11-14 — ĐỒNG BỘ DATABASE CHO TEAM (SHOP_PET_Database)
   ---------------------------------------------------------------------
   Bối cảnh
   --------
   Từ 20/10/2026 đến nay có các thay đổi DB mà file seed
   SHOP_PET_Database.sql trong repo CHƯA phản ánh đầy đủ. Team
   restore từ file seed ⇒ thiếu schema + dữ liệu.

   Script này bổ sung phần còn thiếu:
     PHẦN 1  — Cột mới (Customer.avatar_url, Customer.birth_date,
                ChatMessages.SenderName, ChatMessages.SenderKind)
     PHẦN 2  — Index UNIQUE, FOREIGN KEY, CHECK CONSTRAINT còn thiếu
     PHẦN 2b — Kiểm tra email trùng của Customer
     PHẦN 3  — Chuẩn hoá tiền tệ USD → VND cho dữ liệu seed
     PHẦN 4  — View / Stored Procedure / Trigger còn thiếu hoặc sai
     PHẦN 5  — Báo cáo kiểm tra

   CÁCH CHẠY CHO TEAM (theo thứ tự)
   -------------------------------
     Bước 1 — Restore lại DB từ file seed mới nhất:
                 sqlcmd -S <server> -U <user> -P <pwd> -f 65001 -i SHOP_PET_Database.sql

     Bước 2 — Chạy script đồng bộ schema:
                 sqlcmd -S <server> -U <user> -P <pwd> -d SHOP_PET_Database -f 65001 ^
                          -i Scripts\2026-11-14_sync_team.sql

     Bước 3 — Chọn 1 trong 2 lựa chọn dữ liệu:
                 a) db_delta_rows.sql  — AN TOÀN: chỉ thêm dòng mới + cập nhật
                                         dòng cũ, KHÔNG xoá dữ liệu nào.
                 b) db_sync_full.sql   — ĐỒNG BỘ TUYỆT ĐỐI: kết quả khớp 100%
                                         với DB dev (bao gồm xoá các dòng
                                         đã bị xoá ở dev).
                 Lệnh:
                 sqlcmd -S <server> -U <user> -P <pwd> -d SHOP_PET_Database -f 65001 ^
                          -i db_delta_rows.sql

   ⚠ LƯU Ý VỀ ENCODING
   ------------------
     File .sql trong repo lưu UTF-8 (KHÔNG BOM). Bắt buộc phải truyền
     `-f 65001` cho sqlcmd, nếu không tiếng Việt sẽ bị hỏng khi nạp.
     Với SSMS: File > Save As > UTF-8, hoặc dùng File > Open > Encoding: UTF-8.

   LƯU Ý
   -----
     • Idempotent — chạy lại nhiều lần vẫn cho kết quả giống nhau.
     • Script không dùng "USE [SHOP_PET_Database]" nên phải truyền -d.
     • KHÔNG xoá bất kỳ dòng dữ liệu nào (trừ PHA 1 của db_sync_full.sql).
   ===================================================================== */

/* Không dùng "USE [SHOP_PET_Database]" để script có thể chạy trên bất kỳ
   DB nào có tên tương tự (giúp kiểm thử an toàn). Luôn chạy bằng:
       sqlcmd -d <database> -i 2026-11-14_sync_team.sql */
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* =====================================================================
   PHẦN 0 — KIỂM TRA MÔI TRƯỜNG
   ===================================================================== */
PRINT '=== [0] KIEM TRA MOI TRUONG ===';

DECLARE @dbname sysname = DB_NAME();
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('dbo.Customer'))
BEGIN
    RAISERROR('Database %s khong co bang dbo.Customer — hay restore tu file seed truoc.', 16, 1, @dbname);
    SET NOEXEC ON;
END
ELSE
    PRINT '  - Database dang chay: ' + @dbname;
GO

/* =====================================================================
   PHẦN 1 — CỘT MỚI
   -----------------------------------------------------------------
   1.1  Customer.avatar_url    (08/11/2026 - Q9)
   1.2  Customer.birth_date    (08/11/2026 - Q20/Q22)
   1.3  ChatMessages.SenderName (13/11/2026 - hộp thư chung)
   1.4  ChatMessages.SenderKind (13/11/2026 - hộp thư chung)
   ===================================================================== */
PRINT '=== [1] THEM COT MOI ===';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Customer') AND name = 'avatar_url')
BEGIN
    PRINT '  + Customer.avatar_url nvarchar(500) NULL';
    ALTER TABLE dbo.Customer ADD avatar_url nvarchar(500) NULL;
END
ELSE PRINT '  = Customer.avatar_url da ton tai';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Customer') AND name = 'birth_date')
BEGIN
    PRINT '  + Customer.birth_date date NULL';
    ALTER TABLE dbo.Customer ADD birth_date date NULL;
END
ELSE PRINT '  = Customer.birth_date da ton tai';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ChatMessages') AND name = 'SenderName')
BEGIN
    PRINT '  + ChatMessages.SenderName nvarchar(100) NULL';
    ALTER TABLE dbo.ChatMessages ADD SenderName nvarchar(100) NULL;
END
ELSE PRINT '  = ChatMessages.SenderName da ton tai';

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.ChatMessages') AND name = 'SenderKind')
BEGIN
    PRINT '  + ChatMessages.SenderKind nvarchar(10) NULL';
    ALTER TABLE dbo.ChatMessages ADD SenderKind nvarchar(10) NULL;
END
ELSE PRINT '  = ChatMessages.SenderKind da ton tai';
GO

/* CHECK constraint cho SenderKind.
   SenderType đã bị CHECK giới hạn 'Staff'/'Customer' nên nhãn chi tiết
   (staff/admin/doctor/customer) phải nằm ở SenderKind. */
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID('dbo.ChatMessages') AND name = 'CK_ChatMessages_SenderKind')
BEGIN
    PRINT '  + CK_ChatMessages_SenderKind';
    ALTER TABLE dbo.ChatMessages WITH NOCHECK
        ADD CONSTRAINT CK_ChatMessages_SenderKind
        CHECK (SenderKind IS NULL OR SenderKind IN ('staff','admin','doctor','customer'));
END
ELSE PRINT '  = CK_ChatMessages_SenderKind da ton tai';
GO

/* =====================================================================
   PHẦN 2 — INDEX UNIQUE CÒN THIẾU
   -----------------------------------------------------------------
   Tên index do SQL Server sinh tự động (UQ__...) KHÔNG giống nhau giữa
   các DB ⇒ kiểm tra theo CẤU TRÚC (bảng + cột + is_unique) thay vì
   theo tên. Nếu đã có index unique trên cột đó thì bỏ qua.
   ===================================================================== */
PRINT '=== [2] INDEX ===';

/* 2.1 admin.username */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.admin') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'username')
BEGIN
    PRINT '  + admin UNIQUE(username)';
    CREATE UNIQUE NONCLUSTERED INDEX [UX_admin_username] ON dbo.[admin] ([username]);
END
ELSE PRINT '  = admin UNIQUE(username) da ton tai';

/* 2.2 Species.species_name */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.Species') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'species_name')
BEGIN
    PRINT '  + Species UNIQUE(species_name)';
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Species_species_name] ON dbo.[Species] ([species_name]);
END
ELSE PRINT '  = Species UNIQUE(species_name) da ton tai';

/* 2.3 Staff.email */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.Staff') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'email')
BEGIN
    PRINT '  + Staff UNIQUE(email)';
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Staff_email] ON dbo.[Staff] ([email]);
END
ELSE PRINT '  = Staff UNIQUE(email) da ton tai';

/* 2.4 StaffSalary.StaffID */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.StaffSalary') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'StaffID')
BEGIN
    PRINT '  + StaffSalary UNIQUE(StaffID)';
    CREATE UNIQUE NONCLUSTERED INDEX [UX_StaffSalary_StaffID] ON dbo.[StaffSalary] ([StaffID]);
END
ELSE PRINT '  = StaffSalary UNIQUE(StaffID) da ton tai';

/* 2.5 Shifts.ShiftCode */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.Shifts') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'ShiftCode')
BEGIN
    PRINT '  + Shifts UNIQUE(ShiftCode)';
    CREATE UNIQUE NONCLUSTERED INDEX [UX_Shifts_ShiftCode] ON dbo.[Shifts] ([ShiftCode]);
END
ELSE PRINT '  = Shifts UNIQUE(ShiftCode) da ton tai';

/* 2.6 Customer.email (UX_Customer_Email) — DB dev đã có, seed có thể chưa.
   CHỈ tạo khi dữ liệu không trùng email (nếu trùng sẽ để PHẦN 2b gộp trước). */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = i.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('dbo.Customer') AND i.is_unique = 1
      AND i.is_primary_key = 0 AND ic.key_ordinal > 0 AND c.name = 'email')
BEGIN
    IF EXISTS (
        SELECT 1 FROM dbo.Customer
        WHERE email IS NOT NULL
        GROUP BY email HAVING COUNT(*) > 1)
    BEGIN
        PRINT '  ! Customer email bi trung — BO QUA tao index (se gop o PHAN 2b)';
    END
    ELSE
    BEGIN
        PRINT '  + Customer UNIQUE(email)';
        CREATE UNIQUE NONCLUSTERED INDEX [UX_Customer_Email] ON dbo.[Customer] ([email]);
    END
END
ELSE PRINT '  = Customer UNIQUE(email) da ton tai';

/* 2.7 FOREIGN KEY còn thiếu trong file seed */
IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('dbo.AttendanceRecords')
      AND referenced_object_id = OBJECT_ID('dbo.Staff'))
BEGIN
    PRINT '  + FK AttendanceRecords.StaffID -> Staff.staff_id';
    ALTER TABLE dbo.AttendanceRecords WITH NOCHECK
        ADD CONSTRAINT FK_AttendanceRecords_Staff
        FOREIGN KEY (StaffID) REFERENCES dbo.Staff(staff_id);
END
ELSE PRINT '  = FK AttendanceRecords -> Staff da ton tai';

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('dbo.BreedPricing')
      AND referenced_object_id = OBJECT_ID('dbo.Breed'))
BEGIN
    PRINT '  + FK BreedPricing.breed_id -> Breed.breed_id';
    ALTER TABLE dbo.BreedPricing WITH NOCHECK
        ADD CONSTRAINT FK_BreedPricing_Breed
        FOREIGN KEY (breed_id) REFERENCES dbo.Breed(breed_id);
END
ELSE PRINT '  = FK BreedPricing -> Breed da ton tai';

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID('dbo.StaffSalary')
      AND referenced_object_id = OBJECT_ID('dbo.Staff'))
BEGIN
    PRINT '  + FK StaffSalary.StaffID -> Staff.staff_id';
    ALTER TABLE dbo.StaffSalary WITH NOCHECK
        ADD CONSTRAINT FK_StaffSalary_Staff
        FOREIGN KEY (StaffID) REFERENCES dbo.Staff(staff_id);
END
ELSE PRINT '  = FK StaffSalary -> Staff da ton tai';

/* 2.8 CHECK CONSTRAINT còn thiếu trong file seed */
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Pet')
      AND definition LIKE '%gender%')
BEGIN
    PRINT '  + CK_Pet_gender';
    ALTER TABLE dbo.Pet WITH NOCHECK
        ADD CONSTRAINT CK_Pet_gender
        CHECK (gender IS NULL OR gender IN ('female','male'));
END
ELSE PRINT '  = CK_Pet_gender da ton tai';

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.Review')
      AND definition LIKE '%rating%')
BEGIN
    PRINT '  + CK_Review_rating';
    ALTER TABLE dbo.Review WITH NOCHECK
        ADD CONSTRAINT CK_Review_rating
        CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5));
END
ELSE PRINT '  = CK_Review_rating da ton tai';

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChatMessages')
      AND definition LIKE '%SenderType%')
BEGIN
    PRINT '  + CK_ChatMessages_SenderType';
    ALTER TABLE dbo.ChatMessages WITH NOCHECK
        ADD CONSTRAINT CK_ChatMessages_SenderType
        CHECK (SenderType IS NULL OR SenderType IN ('Staff','Customer'));
END
ELSE PRINT '  = CK_ChatMessages_SenderType da ton tai';
GO

/* =====================================================================
   PHẦN 2b — GỘP CUSTOMER TRÙNG EMAIL (49 → 61)
   -----------------------------------------------------------------
   DB dev: Customer 49 (email nhattoan0310@gmail.com) đã bị xoá, thay
   bằng Customer 61 cùng email. File seed vẫn còn 49 ⇒ delta sẽ xoá 49
   rồi chèn 61 (xem db_delta_rows.sql, PHA 1 + PHA 2).

   customer_id là cột IDENTITY ⇒ không UPDATE được, nên ở đây chỉ
   "nhường chỗ" cho unique index bằng cách tạm hoãn tạo index email
   nếu dữ liệu còn trùng (đã xử lý ở PHẦN 2.6).
   ===================================================================== */
PRINT '=== [2b] KIEM TRA CUSTOMER TRUNG EMAIL ===';

IF EXISTS (
    SELECT 1 FROM dbo.Customer
    WHERE email IS NOT NULL
    GROUP BY email HAVING COUNT(*) > 1)
    PRINT '  ! Co email trung — db_delta_rows.sql se xoa dong cu va chen dong moi';
ELSE
    PRINT '  = khong co email trung';
GO

/* =====================================================================
   PHẦN 3 — CHUẨN HOÁ TIỀN TỆ VND (09/11/2026)
   -----------------------------------------------------------------
   Dữ liệu seed gốc dùng giá "kiểu USD" cho một số bảng trong khi phần
   lớn dữ liệu đã là VND thật ⇒ UI hiển thị lẫn lộn "15.990 ₫".

   KHÔNG dùng tỷ giá quy đổi cho phần có bản ghi thật — dùng GIÁ THẬT
   của sản phẩm/dịch vụ. Idempotent. KHÔNG xoá dòng dữ liệu nào.
   ===================================================================== */
PRINT '=== [3] CHUAN HOA TIEN TE VND ===';

BEGIN TRANSACTION;

/* 3.1 Order_Detail.unit_price ← giá VND thật của sản phẩm/dịch vụ */
UPDATE od
SET od.unit_price = COALESCE(p.price, ps.price, od.unit_price)
FROM dbo.Order_Detail od
LEFT JOIN dbo.Products p ON p.product_id = od.product_id
LEFT JOIN dbo.PetService ps ON ps.service_id = od.service_id
WHERE od.unit_price < 1000
  AND (p.price IS NOT NULL OR ps.price IS NOT NULL);

/* 3.2 Order.total_amount ← SUM(quantity × unit_price) */
UPDATE o
SET o.total_amount = x.total
FROM dbo.[Order] o
CROSS APPLY (
    SELECT ISNULL(SUM(od.quantity * od.unit_price), 0) AS total
    FROM dbo.Order_Detail od
    WHERE od.order_id = o.order_id
) x
WHERE o.total_amount < 1000
  AND x.total > 0;

/* 3.3 Tỷ lệ quy đổi fallback cho nhóm dữ liệu seed cũ */
DECLARE @ratio DECIMAL(18,6);

SELECT @ratio = CASE
        WHEN MIN(o2.total_amount) > 0
            THEN AVG(CAST(o2.total_amount AS FLOAT)) / AVG(CAST(o1.total_amount AS FLOAT))
        ELSE NULL
    END
FROM dbo.[Order] o1
JOIN dbo.[Order] o2 ON o2.order_id = o1.order_id
WHERE o1.total_amount < 1000
  AND o2.total_amount >= 1000;

IF @ratio IS NULL OR @ratio <= 0
    SET @ratio = 25000;

PRINT CONCAT('  Ty le quy doi fallback: ', @ratio);

/* 3.3a Đơn KHÔNG có Order_Detail */
UPDATE dbo.[Order]
SET total_amount = ROUND(total_amount * @ratio, 0)
WHERE total_amount < 1000
  AND NOT EXISTS (SELECT 1 FROM dbo.Order_Detail d WHERE d.order_id = dbo.[Order].order_id);

/* 3.3b Order_Detail mồ côi (không map được giá thật) */
UPDATE od
SET od.unit_price = ROUND(od.unit_price * @ratio, 0)
FROM dbo.Order_Detail od
WHERE od.unit_price < 1000
  AND NOT EXISTS (SELECT 1 FROM dbo.Products p WHERE p.product_id = od.product_id)
  AND NOT EXISTS (SELECT 1 FROM dbo.PetService ps WHERE ps.service_id = od.service_id);

/* 3.3c Tính lại total_amount cho đơn chứa dòng chi tiết mồ côi */
UPDATE o
SET o.total_amount = x.total
FROM dbo.[Order] o
CROSS APPLY (
    SELECT ISNULL(SUM(od.quantity * od.unit_price), 0) AS total
    FROM dbo.Order_Detail od
    WHERE od.order_id = o.order_id
) x
WHERE x.total > 0
  AND o.total_amount < 1000;

/* 3.4 Payment.amount ← đồng bộ theo total_amount của đơn */
UPDATE p
SET p.amount = o.total_amount
FROM dbo.Payment p
JOIN dbo.[Order] o
    ON o.order_id = p.reference_id
   AND p.payment_type = 'order'
WHERE p.amount < 1000
  AND o.total_amount > 0;

/* 3.4b Payment mồ côi → giữ dòng, áp tỷ giá fallback */
UPDATE p
SET p.amount = ROUND(p.amount * @ratio, 0)
FROM dbo.Payment p
WHERE p.amount < 1000
  AND p.payment_type = 'order'
  AND NOT EXISTS (
      SELECT 1 FROM dbo.[Order] o WHERE o.order_id = p.reference_id
  );

/* 3.5 StaffSalary.HourlyRate → median các staff khác */
DECLARE @medianRate DECIMAL(18,2);

SELECT @medianRate = AVG(CAST(HourlyRate AS FLOAT))
FROM (
    SELECT HourlyRate,
           ROW_NUMBER() OVER (ORDER BY HourlyRate) AS rn,
           COUNT(*) OVER () AS cnt
    FROM dbo.StaffSalary
    WHERE HourlyRate >= 1000
) t
WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2);

IF @medianRate IS NULL OR @medianRate <= 0
    SET @medianRate = 19000;

UPDATE dbo.StaffSalary
SET HourlyRate = @medianRate
WHERE HourlyRate < 1000;

/* 3.6 PayrollRecords.HourlyRate ← đồng bộ theo StaffSalary */
UPDATE pr
SET pr.HourlyRate = ss.HourlyRate
FROM dbo.PayrollRecords pr
JOIN dbo.StaffSalary ss ON ss.StaffId = pr.StaffID
WHERE pr.HourlyRate IS NOT NULL
  AND pr.HourlyRate < 1000;

COMMIT TRANSACTION;
PRINT '  - Hoan tat chuan hoa VND';
GO

/* =====================================================================
   PHẦN 4 — VIEW / STORED PROCEDURE / TRIGGER CÒN THIẾU
   -----------------------------------------------------------------
   File seed MỚI đã gồm đầy đủ. Phần này chỉ là lưới an toàn cho
   trường hợp team vẫn đang dùng file seed CŨ.
   ===================================================================== */
PRINT '=== [4] VIEW / PROC / TRIGGER ===';

IF OBJECT_ID('dbo.tr_MedicalRecord_Update', 'TR') IS NULL
BEGIN
    PRINT '  + tr_MedicalRecord_Update';
    EXEC(N'CREATE TRIGGER [dbo].[tr_MedicalRecord_Update]
ON dbo.MedicalRecord
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE mr
    SET updated_at = GETDATE()
    FROM dbo.MedicalRecord mr
    INNER JOIN inserted i ON mr.record_id = i.record_id;
END;');
END
ELSE PRINT '  = tr_MedicalRecord_Update';

/* StaffCheckIn / StaffCheckOut cần cột StaffID (không phải staff_id).
   File seed cũ dùng staff_id ⇒ proc bị lỗi khi gọi.
   LƯU Ý: điều kiện check phải phân biệt "staff_id" (tên cột) với
   "@p_staff_id" (tên biến) — nếu không sẽ ALTER lại proc dù đã đúng. */
IF OBJECT_ID('dbo.StaffCheckIn', 'P') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.sql_modules m
               WHERE m.object_id = OBJECT_ID('dbo.StaffCheckIn')
                 AND (m.definition LIKE '%(staff_id%' OR m.definition LIKE '% staff_id %'))
BEGIN
    PRINT '  * sua StaffCheckIn (staff_id -> StaffID)';
    EXEC('ALTER PROCEDURE [dbo].[StaffCheckIn]
    @p_staff_id INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM AttendanceRecords
        WHERE StaffID = @p_staff_id
          AND CAST(CheckIn AS DATE) = CAST(GETDATE() AS DATE)
    )
    BEGIN
        PRINT N''Staff has already checked in today.'';
        RETURN;
    END;
    INSERT INTO AttendanceRecords (StaffID, CheckIn, CreatedAt)
    VALUES (@p_staff_id, GETDATE(), GETDATE());
    PRINT N''Check-in successful at '' + CONVERT(NVARCHAR, GETDATE(), 120);
END;');
END
ELSE PRINT '  = StaffCheckIn';

IF OBJECT_ID('dbo.StaffCheckOut', 'P') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.sql_modules m
               WHERE m.object_id = OBJECT_ID('dbo.StaffCheckOut')
                 AND (m.definition LIKE '%(staff_id%' OR m.definition LIKE '% staff_id %'))
BEGIN
    PRINT '  * sua StaffCheckOut (staff_id -> StaffID)';
    EXEC('ALTER PROCEDURE [dbo].[StaffCheckOut]
    @p_staff_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @checkin DATETIME;
    SELECT TOP 1 @checkin = CheckIn
    FROM AttendanceRecords
    WHERE StaffID = @p_staff_id AND CheckOut IS NULL
    ORDER BY CheckIn DESC;
    IF @checkin IS NULL
    BEGIN
        PRINT N''Staff has not checked in or has already checked out.'';
        RETURN;
    END;
    UPDATE AttendanceRecords
    SET CheckOut = GETDATE(),
        TotalHours = ROUND(DATEDIFF(MINUTE, @checkin, GETDATE()) / 60.0, 2),
        Status = N''Completed''
    WHERE StaffID = @p_staff_id AND CheckOut IS NULL;
    PRINT N''Check-out successful at '' + CONVERT(NVARCHAR, GETDATE(), 120);
END;');
END
ELSE PRINT '  = StaffCheckOut';
GO

/* =====================================================================
   PHẦN 5 — BÁO CÁO KIỂM TRA
   ===================================================================== */
PRINT '=== [5] BAO CAO ===';

SELECT 'ChatMessages' AS bang, COUNT(*) AS so_dong FROM dbo.ChatMessages
UNION ALL SELECT 'Customer', COUNT(*) FROM dbo.Customer
UNION ALL SELECT 'Order', COUNT(*) FROM dbo.[Order]
UNION ALL SELECT 'Order_Detail', COUNT(*) FROM dbo.Order_Detail
UNION ALL SELECT 'Payment', COUNT(*) FROM dbo.Payment
UNION ALL SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL SELECT 'PetService', COUNT(*) FROM dbo.PetService
UNION ALL SELECT 'Supplier', COUNT(*) FROM dbo.Supplier;

PRINT '-- Con gia USD (phai = 0) --';
SELECT 'Order.total_amount < 1000' AS metric, COUNT(*) AS cnt FROM dbo.[Order] WHERE total_amount < 1000
UNION ALL SELECT 'Order_Detail.unit_price < 1000', COUNT(*) FROM dbo.Order_Detail WHERE unit_price < 1000
UNION ALL SELECT 'Payment.amount < 1000', COUNT(*) FROM dbo.Payment WHERE amount < 1000
UNION ALL SELECT 'StaffSalary.HourlyRate < 1000', COUNT(*) FROM dbo.StaffSalary WHERE HourlyRate < 1000
UNION ALL SELECT 'PayrollRecords.HourlyRate < 1000', COUNT(*) FROM dbo.PayrollRecords WHERE HourlyRate < 1000;

PRINT '-- Cot moi --';
SELECT 'Customer.avatar_url' AS cot, COUNT(*) AS so_dong_khong_null FROM dbo.Customer WHERE avatar_url IS NOT NULL
UNION ALL SELECT 'Customer.birth_date', COUNT(*) FROM dbo.Customer WHERE birth_date IS NOT NULL
UNION ALL SELECT 'ChatMessages.SenderName', COUNT(*) FROM dbo.ChatMessages WHERE SenderName IS NOT NULL
UNION ALL SELECT 'ChatMessages.SenderKind', COUNT(*) FROM dbo.ChatMessages WHERE SenderKind IS NOT NULL;

PRINT '=== HOAN TAT ===';
GO
