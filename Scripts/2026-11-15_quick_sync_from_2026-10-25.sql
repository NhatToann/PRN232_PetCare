/* =====================================================================
   2026-11-15 - DONG BO NHANH CHO TEAM (chi thay doi tu 25/10/2026)
   ---------------------------------------------------------------------
   MUC TICH
   -------
   Script nay ap dung TOAN BO thay doi da lam tren DB dev (SHOP_PET_Database)
   ke tu 25/10/2026 vao database cua team. KHONG can restore lai file seed
   va KHONG sua du lieu cu (cac dong duoc tao truoc 25/10 giu nguyen).

   NOI DUNG
   --------
     PHAN 0  - Kiem tra moi truong
     PHAN 1  - Schema moi: cot moi, CHECK constraint, INDEX UNIQUE, FOREIGN KEY
     PHAN 2  - Chuan hoa tien te USD -> VND cho du lieu cu
     PHAN 3  - Trigger / Stored Procedure sua loi
     PHAN 4  - DU LIEU phat sinh tu 25/10/2026 (INSERT dong moi + UPDATE dong doi)
     PHAN 5  - Bao cao kiem tra

   CACH CHAY (mot lenh duy nhat)
   ----------------------------
     sqlcmd -S <server> -U <user> -P <pwd> -d SHOP_PET_Database ^
              -f 65001 -i Scripts\2026-11-15_quick_sync_from_2026-10-25.sql

   * BAT BUOC co -f 65001, neu khong tieng Viet se bi hong.
   * Script KHONG dung "USE [SHOP_PET_Database]" nen -d la bat buoc.
   * Idempotent: chay lai nhieu lan van cho ket qua giong nhau.
   * KHONG xoa du lieu cu. Chi xoa duy nhat Customer 49 (trung email voi
     Customer 61 moi tao) de khong vi pham UNIQUE(UX_Customer_Email).
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

/* =====================================================================
   PHAN 0 - KIEM TRA MOI TRUONG
   ===================================================================== */
PRINT '=== [0] KIEM TRA MOI TRUONG ===';

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('dbo.Customer'))
BEGIN
    RAISERROR('Database hien tai khong co bang dbo.Customer - hay restore tu file seed truoc.', 16, 1);
    SET NOEXEC ON;
END
ELSE
    PRINT '  - Database dang chay: ' + DB_NAME();
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

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
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

/* =====================================================================
   PHẦN 5 — BÁO CÁO KIỂM TRA
   ===================================================================== */
GO
/* =====================================================================
   PHAN 4 - DU LIEU PHAT SINH TU 25/10/2026
   -----------------------------------------------------------------
   Cac dong moi (INSERT) va cac dong da bi sua (UPDATE) so voi DB dev.
   Thu tu: cha truoc, con sau. Moi INSERT deu co dieu kien NOT EXISTS
   nen chay lai nhieu lan khong bi trung du lieu.
   ===================================================================== */
PRINT '=== [4] DU LIEU TU 25/10/2026 ===';
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 49)
   AND NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 61)
BEGIN
    PRINT '  - xoa Customer 49 (trung email voi Customer 61)';
    DELETE FROM dbo.Customer WHERE customer_id = 49;
END
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
-- ===== Supplier : 4 dong moi =====
SET IDENTITY_INSERT dbo.[Supplier] ON;
INSERT INTO dbo.[Supplier] ([supplier_id], [address], [phone], [name_Company]) SELECT 9, NULL, NULL, N'ZZVerifySupplier' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Supplier] WHERE [supplier_id] = 9);
INSERT INTO dbo.[Supplier] ([supplier_id], [address], [phone], [name_Company]) SELECT 7, NULL, NULL, N'Smoke Supplier' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Supplier] WHERE [supplier_id] = 7);
INSERT INTO dbo.[Supplier] ([supplier_id], [address], [phone], [name_Company]) SELECT 8, NULL, NULL, N'x' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Supplier] WHERE [supplier_id] = 8);
INSERT INTO dbo.[Supplier] ([supplier_id], [address], [phone], [name_Company]) SELECT 10, NULL, NULL, N's' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Supplier] WHERE [supplier_id] = 10);
SET IDENTITY_INSERT dbo.[Supplier] OFF;

-- ===== PetService : 1 dong moi =====
SET IDENTITY_INSERT dbo.[PetService] ON;
INSERT INTO dbo.[PetService] ([service_id], [name], [description], [price], [duration], [service_type], [status], [created_at], [updated_at], [image_url]) SELECT 17, N'Smoke Service', N'test', CAST('100000.00' AS Decimal(10,2)), 60, N'spa', N'active', CAST('2026-11-08 15:20:27.570' AS datetime), CAST('2026-11-08 15:20:27.570' AS datetime), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[PetService] WHERE [service_id] = 17);
SET IDENTITY_INSERT dbo.[PetService] OFF;

-- ===== Products : 10 dong moi =====
SET IDENTITY_INSERT dbo.[Products] ON;
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 49, N'Thức ăn mèo gRPC 171523328', CAST('125000.00' AS Decimal(18,2)), 12, N'Sản phẩm demo tạo từ client streaming gRPC.', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 49);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 45, N'Smoke gRPC bidi upsert', CAST('333000.00' AS Decimal(18,2)), 4, NULL, NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 45);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 44, N'Smoke gRPC client-stream 2', CAST('222000.00' AS Decimal(18,2)), 9, N'Kiem chung client streaming', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 44);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 41, N'Smoke gRPC client-stream 2', CAST('222000.00' AS Decimal(18,2)), 9, N'Kiem chung client streaming', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 41);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 40, N'Smoke gRPC client-stream 1', CAST('111000.00' AS Decimal(18,2)), 7, N'Kiem chung client streaming', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 40);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 47, N'Thức ăn mèo gRPC 171516096', CAST('125000.00' AS Decimal(18,2)), 12, N'Sản phẩm demo tạo từ client streaming gRPC.', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 47);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 46, N'JS Demo Create Product', CAST('99000.00' AS Decimal(18,2)), 5, NULL, NULL, 7, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 46);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 48, N'Đồ chơi chó gRPC 171516096', CAST('89000.00' AS Decimal(18,2)), 20, N'Sản phẩm demo tạo từ client streaming gRPC.', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 48);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 42, N'Smoke gRPC bidi upsert', CAST('333000.00' AS Decimal(18,2)), 4, NULL, NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 42);
INSERT INTO dbo.[Products] ([product_id], [name], [price], [stock_quantity], [description], [supplier_id], [category_id], [admin_id], [image_url], [is_deleted]) SELECT 43, N'Smoke gRPC client-stream 1', CAST('111000.00' AS Decimal(18,2)), 7, N'Kiem chung client streaming', NULL, 1, NULL, NULL, 0 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Products] WHERE [product_id] = 43);
SET IDENTITY_INSERT dbo.[Products] OFF;

-- ===== Customer : 5 dong moi =====
SET IDENTITY_INSERT dbo.[Customer] ON;
INSERT INTO dbo.[Customer] ([customer_id], [name], [phone], [email], [password], [google_id], [address_Customer], [status], [otp_code], [otp_expiry], [reset_token], [reset_token_expiry], [role], [avatar_url], [birth_date]) SELECT 271, N'Test Addr', N'0909887766', N'testaddr99@example.com', N'$2a$11$B6IiLHt2YzIG3.9mPkKtzenTnyGCvTZnhv7PRNVzodflNr60Rr6Ru', NULL, N'789 Lê Lợi, Phường Hòa Cường Nam, Quận Hải Châu, Đà Nẵng', N'active', N'211626', CAST('2026-11-09 18:45:22.393' AS datetime), NULL, NULL, N'user', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Customer] WHERE [customer_id] = 271);
INSERT INTO dbo.[Customer] ([customer_id], [name], [phone], [email], [password], [google_id], [address_Customer], [status], [otp_code], [otp_expiry], [reset_token], [reset_token_expiry], [role], [avatar_url], [birth_date]) SELECT 61, N'Toàn Nhật', N'0974498147', N'nhattoan0310@gmail.com', N'$2a$11$93JaMqMIKIz7//4vSHMp4.k3ke.yd1uGvCm7ap.pipxWBV.ygILXq', N'102507274173869099610', N'123 sdf, Phường Tam Thuận, Quận Thanh Khê, Đà Nẵng', N'active', NULL, NULL, NULL, NULL, N'user', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Customer] WHERE [customer_id] = 61);
INSERT INTO dbo.[Customer] ([customer_id], [name], [phone], [email], [password], [google_id], [address_Customer], [status], [otp_code], [otp_expiry], [reset_token], [reset_token_expiry], [role], [avatar_url], [birth_date]) SELECT 60, N'toàn', N'123123123123', N'dark@gmail.com', N'$2a$11$O9Ei8oAzAykA/CkpgFR0JOyyQ7mYMAJJ.jOGj8JoH7PT9TD.KBWla', NULL, N'123', N'inactive', N'220389', CAST('2026-07-27 06:50:24.763' AS datetime), NULL, NULL, N'user', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Customer] WHERE [customer_id] = 60);
INSERT INTO dbo.[Customer] ([customer_id], [name], [phone], [email], [password], [google_id], [address_Customer], [status], [otp_code], [otp_expiry], [reset_token], [reset_token_expiry], [role], [avatar_url], [birth_date]) SELECT 181, N'Test User', N'0900000000', N'tu.nghiem.277379880@example.com', N'$2a$11$MrB0iHIkL6fhKICTgItvNe/hQVvQpaOB3vOOFTvxWydl6hcQ4E.Yy', NULL, N'Da Nang', N'inactive', N'845757', CAST('2026-11-09 13:12:53.387' AS datetime), NULL, NULL, N'user', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Customer] WHERE [customer_id] = 181);
INSERT INTO dbo.[Customer] ([customer_id], [name], [phone], [email], [password], [google_id], [address_Customer], [status], [otp_code], [otp_expiry], [reset_token], [reset_token_expiry], [role], [avatar_url], [birth_date]) SELECT 302, N'Test Dia Chi', N'0912345678', N'addresstest1@gmail.com', N'$2a$11$xAFgq2.NwEN7L4MRTlCgqeT1e7ub9Ykoe9qvivAnr1hswVVYsRgfW', NULL, N'123 Nguyen Hue, Phuong Hai Chau I, Quan Hai Chau, Da Nang', N'active', N'456546', CAST('2026-11-10 04:54:03.847' AS datetime), NULL, NULL, N'user', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Customer] WHERE [customer_id] = 302);
SET IDENTITY_INSERT dbo.[Customer] OFF;

-- ===== Pet : 2 dong moi =====
SET IDENTITY_INSERT dbo.[Pet] ON;
INSERT INTO dbo.[Pet] ([id], [customer_id], [pet_name], [age], [gender], [description], [health_status], [image_path], [created_at], [updated_at], [weight_kg], [breed_id], [deleted_at]) SELECT 1019, 61, N'chó', 2, N'male', N'mô tả', N'sắp chết rồi cần đi chôn', NULL, CAST('2026-07-27 13:51:36.533' AS datetime), CAST('2026-07-27 13:51:36.533' AS datetime), CAST('1.00' AS Decimal(5,2)), 29, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Pet] WHERE [id] = 1019);
INSERT INTO dbo.[Pet] ([id], [customer_id], [pet_name], [age], [gender], [description], [health_status], [image_path], [created_at], [updated_at], [weight_kg], [breed_id], [deleted_at]) SELECT 1020, 61, N'Tên', 1, N'male', N'okok', N'ok', NULL, CAST('2026-07-29 07:32:04.540' AS datetime), CAST('2026-11-10 00:49:11.770' AS datetime), CAST('2.00' AS Decimal(5,2)), 29, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Pet] WHERE [id] = 1020);
SET IDENTITY_INSERT dbo.[Pet] OFF;

-- ===== Order : 9 dong moi =====
SET IDENTITY_INSERT dbo.[Order] ON;
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124218, CAST('2026-11-10 12:23:09.5094932' AS datetime2), N'Chờ xác nhận', CAST('70000.00' AS Decimal(12,2)), N'COD', 271, NULL, N'COD', NULL, N'456 Trần Phú, Phường Hải Châu I, Quận Hải Châu, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124218);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124219, CAST('2026-11-10 12:29:49.4380758' AS datetime2), N'Chờ xác nhận', CAST('35000.00' AS Decimal(12,2)), N'COD', 271, NULL, N'COD', NULL, N'789 Lê Lợi, Phường Hòa Cường Nam, Quận Hải Châu, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124219);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124216, CAST('2026-11-10 10:20:56.1096725' AS datetime2), N'Đã hủy', CAST('50000.00' AS Decimal(12,2)), N'cancelled', 61, NULL, N'PayOS', NULL, N'123 lê trung đình, Phường Khuê Mỹ, Quận Ngũ Hành Sơn, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124216);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124178, CAST('2026-07-29 07:29:47.7466945' AS datetime2), N'Đã hủy', CAST('35000.00' AS Decimal(12,2)), N'cancelled', 61, NULL, N'PayOS', NULL, N'16 lê trung fifnhf, Phường Hoà Hải, Quận Ngũ Hành Sơn, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124178);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124177, CAST('2026-07-27 13:50:37.2706623' AS datetime2), N'Đã hủy', CAST('17500.00' AS Decimal(12,2)), N'cancelled', 61, NULL, N'PayOS', NULL, N'123123, Phường Hoà Hải, Quận Ngũ Hành Sơn, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124177);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124220, CAST('2026-11-10 14:04:30.5389527' AS datetime2), N'Đã hủy', CAST('50000.00' AS Decimal(12,2)), N'cancelled', 61, NULL, N'PayOS', NULL, N'123 sdf, Phường Tam Thuận, Quận Thanh Khê, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124220);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124176, CAST('2026-07-23 15:04:08.4854838' AS datetime2), N'Đã hủy', CAST('50000.00' AS Decimal(12,2)), N'Đã thanh toán', 5, NULL, N'PayOS', CAST('2026-11-09 21:35:39.850' AS datetime), N'16 lê trung fifnhf, Phường Hoà Hải, Quận Ngũ Hành Sơn, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124176);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124221, CAST('2026-11-10 14:04:48.3494517' AS datetime2), N'Đã hủy', CAST('50000.00' AS Decimal(12,2)), N'cancelled', 61, NULL, N'PayOS', NULL, N'123 sdf, Phường Tam Thuận, Quận Thanh Khê, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124221);
INSERT INTO dbo.[Order] ([order_id], [order_date], [status], [total_amount], [payment_status], [customer_id], [admin_id], [payment_method], [paid_at], [shipping_address], [latitude], [longitude]) SELECT 1973124217, CAST('2026-11-10 10:27:12.0266611' AS datetime2), N'Chờ xác nhận', CAST('10000.00' AS Decimal(12,2)), N'Đã thanh toán', 61, NULL, N'PayOS', CAST('2026-11-10 10:27:34.870' AS datetime), N'12 abc, Phường Mỹ An, Quận Ngũ Hành Sơn, Đà Nẵng', NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order] WHERE [order_id] = 1973124217);
SET IDENTITY_INSERT dbo.[Order] OFF;

-- ===== Order_Detail : 10 dong moi =====
SET IDENTITY_INSERT dbo.[Order_Detail] ON;
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 346, 1973124176, 3, 1, CAST('50000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 346);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 382, 1973124221, 3, 1, CAST('50000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 382);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 377, 1973124216, 3, 1, CAST('50000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 377);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 347, 1973124177, 4, 1, CAST('17500.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 347);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 379, 1973124218, 2, 2, CAST('35000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 379);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 378, 1973124217, 7, 1, CAST('10000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 378);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 349, 1973124179, 2, 1, CAST('35000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 349);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 348, 1973124178, 2, 1, CAST('35000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 348);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 380, 1973124219, 2, 1, CAST('35000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 380);
INSERT INTO dbo.[Order_Detail] ([detail_id], [order_id], [product_id], [quantity], [unit_price], [service_id]) SELECT 381, 1973124220, 3, 1, CAST('50000.00' AS Decimal(10,2)), NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Order_Detail] WHERE [detail_id] = 381);
SET IDENTITY_INSERT dbo.[Order_Detail] OFF;

-- ===== Payment : 21 dong moi =====
SET IDENTITY_INSERT dbo.[Payment] ON;
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 301, N'order', 1973124176, 5, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'pending', 234937828, NULL, NULL, CAST('2026-07-23 15:04:08.707' AS datetime), NULL, N'Thanh toan don hang #1973124176' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 301);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 334, N'order', 1, 1, CAST('399750.00' AS Decimal(10,2)), N'PayOS', N'paid', 746366721, NULL, NULL, CAST('2026-11-09 22:09:29.573' AS datetime), CAST('2026-11-09 22:13:31.133' AS datetime), N'Thanh toan don hang #1' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 334);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 341, N'order', 1973124221, 61, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'cancelled', 1145443104, NULL, NULL, CAST('2026-11-10 14:04:48.353' AS datetime), NULL, N'Thanh toan don hang #1973124221' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 341);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 336, N'order', 1973124216, 61, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'cancelled', 1132010864, NULL, NULL, CAST('2026-11-10 10:20:56.623' AS datetime), NULL, N'Thanh toan don hang #1973124216' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 336);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 337, N'spa', 1398, 61, CAST('9500.00' AS Decimal(10,2)), N'PayOS', N'paid', 1876966158, NULL, NULL, CAST('2026-11-10 10:24:09.840' AS datetime), CAST('2026-11-10 10:38:44.060' AS datetime), N'Thanh toan Spa #1398; bookings=1398' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 337);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 307, N'order', 1973124178, 61, CAST('35000.00' AS Decimal(10,2)), N'PayOS', N'pending', 726077089, NULL, NULL, CAST('2026-07-29 07:29:47.910' AS datetime), NULL, N'Thanh toan don hang #1973124178' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 307);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 340, N'order', 1973124220, 61, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'cancelled', 1145425293, NULL, NULL, CAST('2026-11-10 14:04:30.677' AS datetime), NULL, N'Thanh toan don hang #1973124220' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 340);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 332, N'order', 1973124176, 5, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'paid', 1851022192, NULL, NULL, CAST('2026-11-09 21:16:19.260' AS datetime), CAST('2026-11-09 21:35:39.640' AS datetime), N'Thanh toan don hang #1973' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 332);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 305, N'spa', 1383, 61, CAST('475000.00' AS Decimal(10,2)), N'PayOS', N'pending', 1969723207, NULL, NULL, CAST('2026-07-27 13:51:53.710' AS datetime), NULL, N'Thanh toan Spa #1383; bookings=1383' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 305);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 308, N'spa', 1385, 61, CAST('475000.00' AS Decimal(10,2)), N'PayOS', N'pending', 1595481849, NULL, NULL, CAST('2026-07-29 07:31:03.323' AS datetime), NULL, N'Thanh toan Spa #1385; bookings=1385' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 308);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 303, N'spa', 1381, 5, CAST('704000.00' AS Decimal(10,2)), N'PayOS', N'pending', 141757621, NULL, NULL, CAST('2026-07-23 15:18:30.710' AS datetime), NULL, N'Thanh toan Spa #1381 1; bookings=1381,1382' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 303);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 306, N'spa', 1384, 61, CAST('9500.00' AS Decimal(10,2)), N'PayOS', N'paid', 2005013208, NULL, NULL, CAST('2026-07-27 13:52:29.000' AS datetime), CAST('2026-11-10 15:01:58.943' AS datetime), N'Thanh toan Spa #1384; bookings=1384' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 306);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 335, N'spa', 1397, 61, CAST('9500.00' AS Decimal(10,2)), N'PayOS', N'paid', 939400525, NULL, NULL, CAST('2026-11-10 00:35:52.540' AS datetime), CAST('2026-11-10 11:07:40.270' AS datetime), N'Thanh toan Spa #1397; bookings=1397' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 335);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 333, N'order', 1973124176, 5, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'pending', 192561896, NULL, NULL, CAST('2026-11-09 22:00:15.767' AS datetime), NULL, N'Thanh toan don hang #1973' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 333);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 328, N'spa', 1376, 5, CAST('264000.00' AS Decimal(10,2)), N'PayOS', N'cancelled', 935837096, NULL, NULL, CAST('2026-11-08 18:15:03.123' AS datetime), NULL, N'Thanh toan Spa #1376; bookings=1376' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 328);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 339, N'spa', 1398, 61, CAST('9500.00' AS Decimal(10,2)), N'PayOS', N'pending', 1568475138, NULL, NULL, CAST('2026-11-10 10:38:19.367' AS datetime), NULL, N'Thanh toan Spa #1398; bookings=1398' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 339);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 304, N'order', 1973124177, 61, CAST('17500.00' AS Decimal(10,2)), N'PayOS', N'pending', 576126613, NULL, NULL, CAST('2026-07-27 13:50:37.427' AS datetime), NULL, N'Thanh toan don hang #1973124177' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 304);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 302, N'spa', 1380, 5, CAST('132000.00' AS Decimal(10,2)), N'PayOS', N'pending', 686259380, NULL, NULL, CAST('2026-07-23 15:04:42.690' AS datetime), NULL, N'Thanh toan Spa #1380; bookings=1380' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 302);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 330, N'order', 1973124178, 61, CAST('35000.00' AS Decimal(10,2)), N'PayOS', N'pending', 1044282182, NULL, NULL, CAST('2026-11-08 21:47:59.580' AS datetime), NULL, N'Thanh toan don hang #1973' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 330);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 331, N'order', 2, 2, CAST('50000.00' AS Decimal(10,2)), N'PayOS', N'pending', 1789802246, NULL, NULL, CAST('2026-11-09 01:10:18.960' AS datetime), NULL, N'Thanh toan don hang #2' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 331);
INSERT INTO dbo.[Payment] ([payment_id], [payment_type], [reference_id], [customer_id], [amount], [payment_method], [payment_status], [payos_order_code], [transaction_code], [transaction_ref], [created_at], [paid_at], [note]) SELECT 338, N'order', 1973124217, 61, CAST('10000.00' AS Decimal(10,2)), N'PayOS', N'paid', 1132386781, NULL, NULL, CAST('2026-11-10 10:27:12.043' AS datetime), CAST('2026-11-10 10:27:34.810' AS datetime), N'Thanh toan don hang #1973124217' WHERE NOT EXISTS (SELECT 1 FROM dbo.[Payment] WHERE [payment_id] = 338);
SET IDENTITY_INSERT dbo.[Payment] OFF;

-- ===== Booking : 3 dong moi =====
SET IDENTITY_INSERT dbo.[Booking] ON;
INSERT INTO dbo.[Booking] ([booking_id], [customer_id], [pet_id], [appointment_start], [appointment_end], [status], [note], [created_at], [updated_at], [doctor_id], [staff_id], [order_id]) SELECT 1397, 61, 1019, CAST('2026-11-12 08:00:00.000' AS datetime), CAST('2026-11-12 08:30:00.000' AS datetime), N'Đã thanh toán', N'', CAST('2026-11-10 00:35:52.313' AS datetime), CAST('2026-11-10 11:07:40.440' AS datetime), NULL, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking] WHERE [booking_id] = 1397);
INSERT INTO dbo.[Booking] ([booking_id], [customer_id], [pet_id], [appointment_start], [appointment_end], [status], [note], [created_at], [updated_at], [doctor_id], [staff_id], [order_id]) SELECT 1399, 5, 4, CAST('2026-11-20 08:30:00.000' AS datetime), CAST('2026-11-20 09:00:00.000' AS datetime), N'Chưa thanh toán', N'', CAST('2026-11-14 22:29:24.040' AS datetime), CAST('2026-11-14 22:29:24.270' AS datetime), NULL, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking] WHERE [booking_id] = 1399);
INSERT INTO dbo.[Booking] ([booking_id], [customer_id], [pet_id], [appointment_start], [appointment_end], [status], [note], [created_at], [updated_at], [doctor_id], [staff_id], [order_id]) SELECT 1398, 61, 1019, CAST('2026-11-13 11:00:00.000' AS datetime), CAST('2026-11-13 11:30:00.000' AS datetime), N'Đã thanh toán', N'', CAST('2026-11-10 10:24:09.673' AS datetime), CAST('2026-11-10 10:38:44.080' AS datetime), NULL, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking] WHERE [booking_id] = 1398);
SET IDENTITY_INSERT dbo.[Booking] OFF;

-- ===== Booking_Service : 3 dong moi =====
SET IDENTITY_INSERT dbo.[Booking_Service] ON;
INSERT INTO dbo.[Booking_Service] ([booking_id], [service_id], [quantity], [unit_price], [duration_min], [created_at], [note], [booking_service_id]) SELECT 1398, 16, 1, CAST('9500.00' AS Decimal(12,2)), 30, CAST('2026-11-10 10:24:09.7376479' AS datetime2), N'', 1394 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking_Service] WHERE [booking_id] = 1398 AND [service_id] = 16);
INSERT INTO dbo.[Booking_Service] ([booking_id], [service_id], [quantity], [unit_price], [duration_min], [created_at], [note], [booking_service_id]) SELECT 1399, 16, 1, CAST('8500.00' AS Decimal(12,2)), 30, CAST('2026-11-14 22:29:24.3360447' AS datetime2), N'', 1395 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking_Service] WHERE [booking_id] = 1399 AND [service_id] = 16);
INSERT INTO dbo.[Booking_Service] ([booking_id], [service_id], [quantity], [unit_price], [duration_min], [created_at], [note], [booking_service_id]) SELECT 1397, 16, 1, CAST('9500.00' AS Decimal(12,2)), 30, CAST('2026-11-10 00:35:52.4249519' AS datetime2), N'', 1393 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Booking_Service] WHERE [booking_id] = 1397 AND [service_id] = 16);
SET IDENTITY_INSERT dbo.[Booking_Service] OFF;

-- ===== Review : 1 dong moi =====
SET IDENTITY_INSERT dbo.[Review] ON;
INSERT INTO dbo.[Review] ([rating], [comment], [created_at], [service_id], [product_id], [customer_id], [booking_id], [review_id]) SELECT 5, N'E2E đánh giá tự động', CAST('2026-11-07 23:26:03.6336027' AS datetime2), NULL, 3, 34, NULL, 21 WHERE NOT EXISTS (SELECT 1 FROM dbo.[Review] WHERE [review_id] = 21);
SET IDENTITY_INSERT dbo.[Review] OFF;

-- ===== ChatMessages : 8 dong moi =====
SET IDENTITY_INSERT dbo.[ChatMessages] ON;
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1034, 61, 4, N'customer', N'yo', CAST('2026-11-12 14:43:11.780' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1034);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1025, 61, NULL, N'Customer', N'hi', CAST('2026-07-27 14:28:38.877' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1025);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1024, 61, NULL, N'Customer', N'hi', CAST('2026-07-27 14:17:54.077' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1024);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1058, 61, NULL, N'customer', N'alo?', CAST('2026-11-13 12:32:37.643' AS datetime), 0, N'Toàn Nhật', N'customer' WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1058);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1023, 61, NULL, N'Customer', N'hi', CAST('2026-07-27 14:07:42.043' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1023);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1049, 2, 2, N'staff', N'hi', CAST('2026-11-13 00:21:01.313' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1049);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1022, 61, NULL, N'Customer', N'asd', CAST('2026-07-27 14:07:05.077' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1022);
INSERT INTO dbo.[ChatMessages] ([MessageID], [CustomerID], [StaffID], [SenderType], [Message], [SentAt], [IsRead], [SenderName], [SenderKind]) SELECT 1048, 53, 2, N'staff', N'hi', CAST('2026-11-13 00:20:55.930' AS datetime), 0, NULL, NULL WHERE NOT EXISTS (SELECT 1 FROM dbo.[ChatMessages] WHERE [MessageID] = 1048);
SET IDENTITY_INSERT dbo.[ChatMessages] OFF;

-- ===== SystemSettings : 4 dong moi =====
INSERT INTO dbo.[SystemSettings] ([SettingKey], [SettingValue]) SELECT N'ShopAddress', N'123 Nguyễn Văn Linh, Phường Hòa Cường Nam, Quận Hải Châu, Đà Nẵng' WHERE NOT EXISTS (SELECT 1 FROM dbo.[SystemSettings] WHERE [SettingKey] = N'ShopAddress' AND [SettingValue] = N'123 Nguyễn Văn Linh, Phường Hòa Cường Nam, Quận Hải Châu, Đà Nẵng');
INSERT INTO dbo.[SystemSettings] ([SettingKey], [SettingValue]) SELECT N'ShopEmail', N'petshop.support@gmail.com' WHERE NOT EXISTS (SELECT 1 FROM dbo.[SystemSettings] WHERE [SettingKey] = N'ShopEmail' AND [SettingValue] = N'petshop.support@gmail.com');
INSERT INTO dbo.[SystemSettings] ([SettingKey], [SettingValue]) SELECT N'ShopHotline', N'0901 234 567' WHERE NOT EXISTS (SELECT 1 FROM dbo.[SystemSettings] WHERE [SettingKey] = N'ShopHotline' AND [SettingValue] = N'0901 234 567');
INSERT INTO dbo.[SystemSettings] ([SettingKey], [SettingValue]) SELECT N'ShopWorkingHours', N'8:00 - 20:00 (Thứ 2 - Chủ nhật)' WHERE NOT EXISTS (SELECT 1 FROM dbo.[SystemSettings] WHERE [SettingKey] = N'ShopWorkingHours' AND [SettingValue] = N'8:00 - 20:00 (Thứ 2 - Chủ nhật)');

-- ===== Staff : 6 dong cap nhat =====
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$p5mH4CVCCDHse4XNwbWlWO5RF5dZwOmNnEAHHzyxzvwrNy4KJIYX6'
 WHERE [staff_id] = 5;
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$K3bbsYXatyq2bwCbJ19bNeqDZs0eY/LNWEis6x71BC/ua.B4THIjK'
 WHERE [staff_id] = 8;
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$ceuM7gBFPxOiF.2ACiJ2y.Aj7ppxnHC/mHvATtFAb2mwBTvmW3L5.'
 WHERE [staff_id] = 4;
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$q7GN49M0vmQNZ.jNmkQbu.R1WTqIEWFs3vnsHJnXd2w257Pk5EhJK'
 WHERE [staff_id] = 3;
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$GrpqV/kXnaD4qBN23iiJkeVpd.fsyas3FPGTzlfo2Y5MKvCL1ETF2'
 WHERE [staff_id] = 2;
UPDATE dbo.[Staff]
   SET         [password] = N'$2a$11$yAwiiAsKdxR3xIlMrcUVd.vwjbIgwiseb5/REp/ZyEYOt4kssHOYu'
 WHERE [staff_id] = 1;

-- ===== Doctor : 1 dong cap nhat =====
UPDATE dbo.[Doctor]
   SET         [password] = N'$2a$11$a0t/s5w/TyvZEcvkDVdDv.WWXRLgjC5TDdTjKdI9jUO6BlA.eHBUW'
 WHERE [doctor_id] = 1;

-- ===== Products : 11 dong cap nhat =====
UPDATE dbo.[Products]
   SET         [stock_quantity] = 40
 WHERE [product_id] = 12;
UPDATE dbo.[Products]
   SET         [price] = CAST('222000.00' AS Decimal(18,2))
 WHERE [product_id] = 30;
UPDATE dbo.[Products]
   SET         [stock_quantity] = 16
 WHERE [product_id] = 3;
UPDATE dbo.[Products]
   SET         [price] = CAST('222000.00' AS Decimal(18,2))
 WHERE [product_id] = 25;
UPDATE dbo.[Products]
   SET         [stock_quantity] = 65
 WHERE [product_id] = 2;
UPDATE dbo.[Products]
   SET         [stock_quantity] = 25
 WHERE [product_id] = 17;
UPDATE dbo.[Products]
   SET         [price] = CAST('30000.00' AS Decimal(18,2))
 WHERE [product_id] = 31;
UPDATE dbo.[Products]
   SET         [price] = CAST('222000.00' AS Decimal(18,2))
 WHERE [product_id] = 23;
UPDATE dbo.[Products]
   SET         [stock_quantity] = 30
 WHERE [product_id] = 14;
UPDATE dbo.[Products]
   SET         [is_deleted] = 1
 WHERE [product_id] = 35;
UPDATE dbo.[Products]
   SET         [price] = CAST('222000.00' AS Decimal(18,2))
 WHERE [product_id] = 28;

-- ===== BreedPricing : 1 dong cap nhat =====
UPDATE dbo.[BreedPricing]
   SET         [price_adjust] = CAST('85.00' AS Decimal(10,2))
 WHERE [breed_pricing_id] = 69;

-- ===== Customer : 5 dong cap nhat =====
UPDATE dbo.[Customer]
   SET         [otp_code] = N'397889',
               [otp_expiry] = CAST('2026-11-09 13:09:10.967' AS datetime),
               [avatar_url] = N'data:image/png;base64,iVBORw0KGgo='
 WHERE [customer_id] = 1;
UPDATE dbo.[Customer]
   SET         [name] = N'',
               [email] = N'',
               [password] = N'',
               [google_id] = N'',
               [address_Customer] = N'',
               [status] = N'',
               [otp_code] = N'',
               [otp_expiry] = NULL
 WHERE [customer_id] = 52;
UPDATE dbo.[Customer]
   SET         [address_Customer] = N'123 Nguyễn Huệ, Phường Hải Châu, Quận Hải Châu, Đà Nẵng'
 WHERE [customer_id] = 6;
UPDATE dbo.[Customer]
   SET         [password] = N'$2a$11$nvyA4izWIoXzJZGn6ujyAOMrQWSS1FKIt3/w0qe6UM8S1lMrndizq'
 WHERE [customer_id] = 5;
UPDATE dbo.[Customer]
   SET         [password] = N'$2a$11$lGEWcUGcJlKqOZR2OfnmluNNhKyp.aCMCqtDj5dujOloBquGQ2SsK'
 WHERE [customer_id] = 2;

-- ===== Order : 7 dong cap nhat =====
UPDATE dbo.[Order]
   SET         [status] = N'Đang giao hàng'
 WHERE [order_id] = 1973123934;
UPDATE dbo.[Order]
   SET         [status] = N'Chờ giao hàng'
 WHERE [order_id] = 1973124107;
UPDATE dbo.[Order]
   SET         [status] = N'Đang giao hàng'
 WHERE [order_id] = 1973123938;
UPDATE dbo.[Order]
   SET         [status] = N'Đã hủy'
 WHERE [order_id] = 1973123941;
UPDATE dbo.[Order]
   SET         [status] = N'Hoàn thành'
 WHERE [order_id] = 1973123940;
UPDATE dbo.[Order]
   SET         [paid_at] = CAST('2026-11-09 22:13:31.300' AS datetime)
 WHERE [order_id] = 1;
UPDATE dbo.[Order]
   SET         [status] = N'Đang giao hàng'
 WHERE [order_id] = 1973123937;

-- ===== Payment : 48 dong cap nhat =====
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 272;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 263;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 241;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 288;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 250;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 240;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 244;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 257;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 258;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 274;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 247;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 290;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 286;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 251;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 236;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 293;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 282;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 238;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 235;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 292;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 267;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 255;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 277;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 264;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 246;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 294;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 285;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 270;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 275;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 260;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 237;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 281;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 239;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 266;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 271;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 253;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 242;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 254;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 245;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 289;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 295;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 279;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 243;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 268;
UPDATE dbo.[Payment]
   SET         [payment_status] = N'paid',
               [paid_at] = CAST('2026-11-10 11:09:52.550' AS datetime)
 WHERE [payment_id] = 298;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 273;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 278;
UPDATE dbo.[Payment]
   SET         [amount] = CAST('25000.00' AS Decimal(10,2))
 WHERE [payment_id] = 284;

-- ===== Booking : 3 dong cap nhat =====
UPDATE dbo.[Booking]
   SET         [status] = N'Đang tiến hành'
 WHERE [booking_id] = 1017;
UPDATE dbo.[Booking]
   SET         [updated_at] = CAST('2026-11-10 11:09:52.557' AS datetime)
 WHERE [booking_id] = 1377;
UPDATE dbo.[Booking]
   SET         [status] = N'Hoàn thành'
 WHERE [booking_id] = 1375;

-- ===== Review : 1 dong cap nhat =====
UPDATE dbo.[Review]
   SET         [comment] = N'tuỳ người
'
 WHERE [review_id] = 1;

-- ===== BoardingRoom : 6 dong cap nhat =====
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ ẤM CÚNG CHO CHÓ NHỎ

✨ TIỆN NGHI:
• Hệ thống điều hoành và sưởi ấm mùa đông
• Camera giám sát 24/7
• Chuồng ngủ ấm áp, khăn lót êm ái
• Không gian nhỏ gọn, riêng tư

🎮 KHU VỰC VUI CHƠI:
• Khu vực vui chơi nhỏ gọn phù hợp
• Đồ chơi đa dạng cho chó nhỏ
• Khu vực ăn uống riêng biệt
• Thiết kế an toàn, không góc cạnh

🔇 MÔI TRƯỜNG:
• Yên tĩnh, tránh tiếng ồn
• Phù hợp cho chó nhỏ nhạy cảm
• Tạo cảm giác an toàn và thoải mái

🧹 DỊCH VỤ:
• Vệ sinh và dọn dẹp hàng ngày
• Không gian luôn sạch sẽ, thơm tho
• Chăm sóc tận tình, chu đáo'
 WHERE [room_id] = 108;
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ CAO CẤP CHO CHÓ LỚN

✨ TIỆN NGHI:
• Hệ thống điều hoành không khí hiện đại
• Camera giám sát 24/7 đảm bảo an toàn
• Sàn chống trượt an toàn cho thú cưng
• Chuồng ngủ riêng biệt cho từng thú cưng
• Cửa sổ lớn đón ánh sáng tự nhiên

🏃 KHÔNG GIAN:
• Không gian rộng rãi, thoáng mát
• Khu vực vận động phù hợp cho chó lớn
• Khu vực ăn uống riêng biệt
• Thiết kế an toàn, không góc cạnh

🧹 DỊCH VỤ:
• Vệ sinh và dọn dẹp hàng ngày
• Môi trường sạch sẽ, thông gió tốt
• Chăm sóc chuyên nghiệp bởi đội ngũ giàu kinh nghiệm'
 WHERE [room_id] = 107;
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ TIÊU CHUẨN CHO MÈO

✨ TIỆN NGHI:
• Hệ thống điều hoành không khí
• Camera giám sát 24/7
• Đèn chiếu sáng tự nhiên
• Kệ leo trèo đa dạng
• Hộp cát vệ sinh thường xuyên
• Giường ngủ thoải mái
• Nơi ẩn nấu riêng tư

🎮 KHU VỰC VUI CHƠI:
• Đồ chơi đa dạng, phong phú
• Cây cào móng chất lượng
• Khu vực chơi đùa riêng biệt
• Thiết kế an toàn, không góc cạnh

🔇 MÔI TRƯỜNG:
• Yên tĩnh, tránh tiếng ồn
• Phù hợp cho mèo nhỏ nhạy cảm
• Tạo cảm giác an toàn và thoải mái

🧹 DỊCH VỤ:
• Vệ sinh hộp cát 2 lần/ngày
• Dọn dẹp phòng hàng ngày
• Không gian luôn sạch sẽ, thơm tho
• Chăm sóc tận tình, chu đáo'
 WHERE [room_id] = 112;
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ VIP CAO CẤP CHO MÈO

✨ TIỆN NGHI CAO CẤP:
• Hệ thống điều hoành không khí cao cấp
• Camera giám sát HD 24/7
• Cửa sổ lớn có lưới an toàn, đón ánh sáng tự nhiên
• Kệ leo trèo đa tầng cao cấp
• Hộp cát vệ sinh tự động
• Giường ngủ sang trọng, êm ái
• Nơi ẩn nấu riêng tư, cao cấp

🎮 KHU VỰC VUI CHƠI:
• Đồ chơi cao cấp, phong phú
• Cây cào móng chất lượng
• Khu vực vui chơi và quan sát bên ngoài rộng rãi
• Thiết kế an toàn, không góc cạnh

🔇 MÔI TRƯỜNG:
• Yên tĩnh tuyệt đối
• Âm thanh nhẹ nhàng, dễ chịu
• Phù hợp cho mèo VIP

⭐ DỊCH VỤ ĐẶC BIỆT:
• Vệ sinh hộp cát nhiều lần/ngày
• Dọn dẹp phòng 2 lần/ngày
• Kiểm tra sức khoẻ hàng ngày
• Chăm sóc tận tình, chu đáo'
 WHERE [room_id] = 111;
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ YÊN TĨNH CHO MÈO NHỎ

✨ TIỆN NGHI:
• Kệ leo trèo phù hợp cho mèo nhỏ
• Hộp cát vệ sinh thường xuyên
• Khu vực nghỉ ngơi ấm áp
• Nơi ẩn nấu riêng tư
• Hệ thống điều hoành và sưởi ấm
• Camera giám sát 24/7
• Đèn chiếu sáng dịu nhẹ

🎮 KHU VỰC VUI CHƠI:
• Đồ chơi phù hợp cho mèo nhỏ
• Cây cào móng nhỏ gọn
• Nơi quan sát bên ngoài an toàn
• Không gian nhỏ gọn, ấm cúng

🔇 MÔI TRƯỜNG:
• Cực kỳ yên tĩnh, tránh mọi tiếng ồn
• Phù hợp cho mèo nhỏ nhạy cảm
• Tạo cảm giác an toàn và thoải mái

🧹 DỊCH VỤ:
• Vệ sinh thường xuyên
• Dọn dẹp phòng hàng ngày
• Không gian luôn sạch sẽ, không có mùi'
 WHERE [room_id] = 110;
UPDATE dbo.[BoardingRoom]
   SET         [description] = N'🏠 PHÒNG LƯU TRÚ CAO CẤP CHO MÈO LỚN

✨ TIỆN NGHI:
• Hệ thống kệ leo trèo đa tầng cao cấp
• Hộp cát vệ sinh đa tầng cho mèo lớn
• Khu vực nghỉ ngơi cao ráo, thoải mái
• Cửa sổ có lưới an toàn
• Hệ thống điều hoành không khí
• Camera giám sát 24/7
• Đèn chiếu sáng dịu nhẹ

🎮 KHU VỰC VUI CHƠI:
• Đồ chơi cao cấp, phong phú
• Cây cào móng chất lượng
• Khu vực vận động rộng rãi, thoải mái
• Thiết kế an toàn, không góc cạnh

🔇 MÔI TRƯỜNG:
• Yên tĩnh, tránh stress
• Phù hợp cho mèo lớn nhạy cảm
• Tạo cảm giác an toàn và thoải mái

🧹 DỊCH VỤ:
• Vệ sinh 2-3 lần/ngày
• Dọn dẹp phòng hàng ngày
• Môi trường sạch sẽ, thông gió tốt
• Chăm sóc chuyên nghiệp bởi đội ngũ giàu kinh nghiệm'
 WHERE [room_id] = 109;
COMMIT TRANSACTION;

GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;

/* =====================================================================
   PHAN 5 - BAO CAO KIEM TRA
   ===================================================================== */
PRINT '=== [5] BAO CAO ===';

SELECT 'ChatMessages' AS bang, COUNT(*) AS so_dong FROM dbo.ChatMessages
UNION ALL SELECT 'Customer', COUNT(*) FROM dbo.Customer
UNION ALL SELECT 'Order', COUNT(*) FROM dbo.[Order]
UNION ALL SELECT 'Order_Detail', COUNT(*) FROM dbo.Order_Detail
UNION ALL SELECT 'Payment', COUNT(*) FROM dbo.Payment
UNION ALL SELECT 'Booking', COUNT(*) FROM dbo.Booking
UNION ALL SELECT 'Booking_Service', COUNT(*) FROM dbo.Booking_Service
UNION ALL SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL SELECT 'PetService', COUNT(*) FROM dbo.PetService
UNION ALL SELECT 'Supplier', COUNT(*) FROM dbo.Supplier
UNION ALL SELECT 'SystemSettings', COUNT(*) FROM dbo.SystemSettings
UNION ALL SELECT 'Pet', COUNT(*) FROM dbo.Pet
UNION ALL SELECT 'Review', COUNT(*) FROM dbo.Review;

PRINT '-- Cot moi (phai co) --';
SELECT 'Customer.avatar_url' AS cot, COUNT(*) AS so_dong_khong_null FROM dbo.Customer WHERE avatar_url IS NOT NULL
UNION ALL SELECT 'Customer.birth_date', COUNT(*) FROM dbo.Customer WHERE birth_date IS NOT NULL
UNION ALL SELECT 'ChatMessages.SenderName', COUNT(*) FROM dbo.ChatMessages WHERE SenderName IS NOT NULL
UNION ALL SELECT 'ChatMessages.SenderKind', COUNT(*) FROM dbo.ChatMessages WHERE SenderKind IS NOT NULL;

PRINT '-- Con gia USD (phai = 0) --';
SELECT 'Order.total_amount < 1000' AS metric, COUNT(*) AS cnt FROM dbo.[Order] WHERE total_amount < 1000
UNION ALL SELECT 'Order_Detail.unit_price < 1000', COUNT(*) FROM dbo.Order_Detail WHERE unit_price < 1000
UNION ALL SELECT 'Payment.amount < 1000', COUNT(*) FROM dbo.Payment WHERE amount < 1000
UNION ALL SELECT 'StaffSalary.HourlyRate < 1000', COUNT(*) FROM dbo.StaffSalary WHERE HourlyRate < 1000
UNION ALL SELECT 'PayrollRecords.HourlyRate < 1000', COUNT(*) FROM dbo.PayrollRecords WHERE HourlyRate < 1000;

PRINT '=== HOAN TAT ===';
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
