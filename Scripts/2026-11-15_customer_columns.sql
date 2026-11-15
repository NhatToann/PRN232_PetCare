-- =============================================================================
-- 2026-11-15 — BỔ SUNG CỘT CHO BẢNG Customer (avatar_url, birth_date)
-- =============================================================================
--
-- VÌ SAO CẦN:
--   Models/Customer.cs + ShopPetDatabaseContext khai báo 2 cột:
--     - `avatar_url`  (nvarchar(500), nullable) — ảnh đại diện khách hàng
--     - `birth_date`  (date, nullable)           — ngày sinh
--
--   nhưng DB THẬT trên máy KHÔNG có 2 cột này (chỉ có trong file
--   SHOP_PET_Database.sql) ⇒ mọi truy vấn đọc `Customer.avatar_url` đều lỗi
--   SQL "Invalid column name 'avatar_url'".
--
--   Hậu quả trực tiếp:
--     - `GET /api/chat/inbox`   ⇒ 500 (màn hình hộp thư của nhân viên hỏng)
--     - `GET /api/chat/peers`   ⇒ 500 (widget chat của nhân viên hỏng)
--     - `GET /api/chat/history` ⇒ 500 (khách không xem được lịch sử chat)
--
-- ⚠️ BẮT BUỘC dùng `GO` giữa các lệnh: sqlcmd gửi CẢ BATCH cho SQL Server
--    compile TRƯỚC khi chạy.
--
-- IDEMPOTENT: chạy lại nhiều lần vẫn an toàn.
-- =============================================================================

SET NOCOUNT ON;
GO

-- -----------------------------------------------------------------------------
-- 1) avatar_url — ảnh đại diện khách hàng (data-URI hoặc http/https).
-- -----------------------------------------------------------------------------
IF COL_LENGTH('dbo.Customer', 'avatar_url') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD [avatar_url] nvarchar(500) NULL;
    PRINT 'Đã thêm cột Customer.avatar_url.';
END
ELSE
BEGIN
    PRINT 'Cột Customer.avatar_url đã tồn tại — bỏ qua.';
END
GO

-- -----------------------------------------------------------------------------
-- 2) birth_date — ngày sinh khách hàng.
-- -----------------------------------------------------------------------------
IF COL_LENGTH('dbo.Customer', 'birth_date') IS NULL
BEGIN
    ALTER TABLE dbo.Customer ADD [birth_date] date NULL;
    PRINT 'Đã thêm cột Customer.birth_date.';
END
ELSE
BEGIN
    PRINT 'Cột Customer.birth_date đã tồn tại — bỏ qua.';
END
GO

PRINT '=== HOÀN TẤT script 2026-11-15 customer columns ===';
GO
