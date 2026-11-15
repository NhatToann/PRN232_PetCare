-- ============================================================================
-- 2026-11-15_schema_sync.sql
--
-- MỤC ĐÍCH:
--   Đồng bộ schema DB thật (SHOP_PET_Database) với schema mà code EF Core
--   đang kỳ vọng. DB thật bị "drift" (thiếu cột) ⇒ các API đọc cột đó
--   trả 500 (SQL error 207 "Invalid column name").
--
--   Ví dụ đã phát hiện & xác minh:
--     GET /PetShop/Products?$top=2  ->  500
--     SQL: Invalid column name 'is_deleted'
--
-- CÁCH DÙNG:
--   sqlcmd -S localhost -d SHOP_PET_Database -E -i Scripts\2026-11-15_schema_sync.sql
--   (hoặc chạy trực tiếp trong SSMS)
--
-- TÍNH IDEMPOTENT:
--   Mỗi lệnh đều kiểm tra sự tồn tại trước khi thêm ⇒ chạy nhiều lần
--   vẫn an toàn, không lỗi "object already exists".
-- ============================================================================

SET NOCOUNT ON;
GO

-- ----------------------------------------------------------------------------
-- 1) Products.is_deleted (bit NOT NULL DEFAULT 0)
--    Dùng cho soft-delete: ProductsTempController chỉ truy vấn sản phẩm
--    chưa bị xoá. Thiếu cột này ⇒ OData /PetShop/Products trả 500.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.Products') AND name = N'is_deleted'
)
BEGIN
    PRINT '[schema_sync] Thêm dbo.Products.is_deleted ...';
    ALTER TABLE dbo.Products
        ADD is_deleted bit NOT NULL CONSTRAINT DF_Products_is_deleted DEFAULT (0);
END
ELSE
    PRINT '[schema_sync] dbo.Products.is_deleted đã có — bỏ qua.';
GO

-- ----------------------------------------------------------------------------
-- 2) PetService.image_url (nvarchar(500) NULL)
--    Ảnh dịch vụ (Spa/Boarding). Thiếu ⇒ API danh sách dịch vụ trả 500.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.PetService') AND name = N'image_url'
)
BEGIN
    PRINT '[schema_sync] Thêm dbo.PetService.image_url ...';
    ALTER TABLE dbo.PetService ADD image_url nvarchar(500) NULL;
END
ELSE
    PRINT '[schema_sync] dbo.PetService.image_url đã có — bỏ qua.';
GO

-- ----------------------------------------------------------------------------
-- 3) Pet.deleted_at (datetime NULL)
--    Mốc thời gian soft-delete thú cưng.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.Pet') AND name = N'deleted_at'
)
BEGIN
    PRINT '[schema_sync] Thêm dbo.Pet.deleted_at ...';
    ALTER TABLE dbo.Pet ADD deleted_at datetime NULL;
END
ELSE
    PRINT '[schema_sync] dbo.Pet.deleted_at đã có — bỏ qua.';
GO

-- ----------------------------------------------------------------------------
-- 4) AttendanceRecords.ScheduleID (int NULL)
--    Liên kết bản ghi chấm công với lịch trực (bảng WorkSchedule).
--    Kiểu NULL + FK tùy chọn ⇒ không đụng dữ liệu cũ.
-- ----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.AttendanceRecords') AND name = N'ScheduleID'
)
BEGIN
    PRINT '[schema_sync] Thêm dbo.AttendanceRecords.ScheduleID ...';
    ALTER TABLE dbo.AttendanceRecords ADD ScheduleID int NULL;

    -- FK tới WorkSchedule (chỉ khi bảng đích tồn tại và có cột khoá).
    IF OBJECT_ID(N'dbo.WorkSchedule') IS NOT NULL
       AND EXISTS (SELECT 1 FROM sys.columns
                    WHERE object_id = OBJECT_ID(N'dbo.WorkSchedule') AND name = N'ScheduleId')
       AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys
                       WHERE name = N'FK_AttendanceRecords_WorkSchedule')
    BEGIN
        ALTER TABLE dbo.AttendanceRecords
            ADD CONSTRAINT FK_AttendanceRecords_WorkSchedule
            FOREIGN KEY (ScheduleID) REFERENCES dbo.WorkSchedule(ScheduleId);
        PRINT '[schema_sync]   + FK tới WorkSchedule.';
    END
END
ELSE
    PRINT '[schema_sync] dbo.AttendanceRecords.ScheduleID đã có — bỏ qua.';
GO

-- ----------------------------------------------------------------------------
-- 5) Cart — bảng KHÔNG tồn tại trong DB thật (dump có, DB không).
--    Code dùng bảng view "v_Cart" (VCart) cho giỏ hàng ⇒ bảng gốc không
--    bắt buộc cho luồng chạy hiện tại. Tạo để khớp 100% với dump, idempotent.
-- ----------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.Cart') IS NULL
BEGIN
    PRINT '[schema_sync] Tạo dbo.Cart ...';
    CREATE TABLE dbo.Cart
    (
        cart_id     int IDENTITY(1,1) NOT NULL,
        customer_id int NOT NULL,
        product_id  int NULL,
        service_id  int NULL,
        quantity    int NOT NULL CONSTRAINT DF_Cart_quantity DEFAULT (1),
        created_at  datetime2 NOT NULL CONSTRAINT DF_Cart_created_at DEFAULT (SYSDATETIME()),
        updated_at  datetime2 NULL,
        CONSTRAINT PK_Cart PRIMARY KEY CLUSTERED (cart_id)
    );

    IF OBJECT_ID(N'dbo.Customer') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Cart_Customer')
    BEGIN
        ALTER TABLE dbo.Cart
            ADD CONSTRAINT FK_Cart_Customer
            FOREIGN KEY (customer_id) REFERENCES dbo.Customer(customer_id);
        PRINT '[schema_sync]   + FK tới Customer.';
    END
END
ELSE
    PRINT '[schema_sync] dbo.Cart đã tồn tại — bỏ qua.';
GO

PRINT '';
PRINT '[schema_sync] HOÀN TẤT.';
GO
