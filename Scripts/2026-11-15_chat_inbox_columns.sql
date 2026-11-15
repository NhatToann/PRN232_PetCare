-- =============================================================================
-- 2026-11-15 — HỘP THƯ CHUNG: thêm cột SenderName / SenderKind vào ChatMessages
-- =============================================================================
--
-- VÌ SAO CẦN:
--   Code (Models/ChatMessage.cs + ChatRepository.AddMessageAsync) đã ghi vào
--   2 cột `SenderName` / `SenderKind` từ 13/11/2026, nhưng DB THẬT trên máy
--   chưa có 2 cột này (chỉ có trong file SHOP_PET_Database.sql) ⇒ mọi lần gửi
--   tin nhắn đều lỗi SQL "Invalid column name 'SenderName'".
--
--   `SenderKind` lưu nhãn loại người gửi đầy đủ (staff / admin / doctor /
--   customer) vì các bảng người dùng có id TRÙNG NHAU (staff_id = admin_id =
--   doctor_id = 1) ⇒ chỉ nhìn id thì không phân biệt được tin của ai.
--
--   `SenderName` lưu tên hiển thị để mọi nhân viên thấy ai đã trả lời khách
--   (hộp thư chung ⇒ nhiều người gửi trong cùng 1 luồng).
--
-- ⚠️ BẮT BUỘC dùng `GO` giữa các lệnh: sqlcmd gửi CẢ BATCH cho SQL Server
--    compile TRƯỚC khi chạy ⇒ lệnh `ADD CONSTRAINT ... CHECK (SenderKind ...)`
--    sẽ lỗi "Invalid column name" nếu nằm cùng batch với `ADD COLUMN`.
--
-- IDEMPOTENT: chạy lại nhiều lần vẫn an toàn.
-- =============================================================================

SET NOCOUNT ON;
GO

-- -----------------------------------------------------------------------------
-- 1) Thêm cột nếu chưa có.
-- -----------------------------------------------------------------------------
IF COL_LENGTH('dbo.ChatMessages', 'SenderName') IS NULL
BEGIN
    ALTER TABLE dbo.ChatMessages ADD [SenderName] nvarchar(100) NULL;
    PRINT 'Đã thêm cột ChatMessages.SenderName.';
END
ELSE
BEGIN
    PRINT 'Cột ChatMessages.SenderName đã tồn tại — bỏ qua.';
END
GO

IF COL_LENGTH('dbo.ChatMessages', 'SenderKind') IS NULL
BEGIN
    ALTER TABLE dbo.ChatMessages ADD [SenderKind] nvarchar(10) NULL;
    PRINT 'Đã thêm cột ChatMessages.SenderKind.';
END
ELSE
BEGIN
    PRINT 'Cột ChatMessages.SenderKind đã tồn tại — bỏ qua.';
END
GO

-- -----------------------------------------------------------------------------
-- 2) CHECK constraint cho SenderKind (nhãn hợp lệ).
--    Dùng WITH NOCHECK để không fail vì dữ liệu cũ có NULL.
-- -----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID('dbo.ChatMessages')
      AND name = 'CK_ChatMessages_SenderKind_Allowed'
)
BEGIN
    ALTER TABLE dbo.ChatMessages WITH NOCHECK
        ADD CONSTRAINT CK_ChatMessages_SenderKind_Allowed
        CHECK ([SenderKind] IS NULL OR [SenderKind] IN ('staff','admin','doctor','customer'));

    PRINT 'Đã thêm CHECK constraint CK_ChatMessages_SenderKind_Allowed.';
END
ELSE
BEGIN
    PRINT 'CHECK constraint CK_ChatMessages_SenderKind_Allowed đã tồn tại — bỏ qua.';
END
GO

-- -----------------------------------------------------------------------------
-- 3) Backfill SenderKind cho dữ liệu cũ (27 dòng seed sẵn có).
--    - SenderType = 'customer' ⇒ 'customer'
--    - SenderType = 'staff'    ⇒ 'staff'  (không biết là staff/admin/doctor
--                                   ⇒ dùng 'staff' làm mặc định an toàn)
-- -----------------------------------------------------------------------------
UPDATE dbo.ChatMessages
SET SenderKind = CASE
        WHEN LOWER(LTRIM(RTRIM(SenderType))) = 'customer' THEN 'customer'
        WHEN LOWER(LTRIM(RTRIM(SenderType))) IN ('staff', 'admin', 'doctor') THEN 'staff'
        ELSE 'customer'
    END
WHERE SenderKind IS NULL;

PRINT 'Đã backfill SenderKind cho dữ liệu cũ.';
GO

-- -----------------------------------------------------------------------------
-- 4) Index hỗ trợ truy vấn "hộp thư của khách" (lọc theo CustomerID, sắp xếp
--    theo SentAt) — ChatRepository.GetHistoryAsync dùng đúng mẫu này.
-- -----------------------------------------------------------------------------
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.ChatMessages')
      AND name = 'IX_ChatMessages_CustomerID_SentAt'
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_ChatMessages_CustomerID_SentAt
        ON dbo.ChatMessages (CustomerID, SentAt DESC)
        INCLUDE (StaffID, SenderType, SenderName, SenderKind, IsRead);

    PRINT 'Đã tạo index IX_ChatMessages_CustomerID_SentAt.';
END
ELSE
BEGIN
    PRINT 'Index IX_ChatMessages_CustomerID_SentAt đã tồn tại — bỏ qua.';
END
GO

PRINT '=== HOÀN TẤT script 2026-11-15 chat inbox columns ===';
GO
