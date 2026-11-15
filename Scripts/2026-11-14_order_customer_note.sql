USE SHOP_PET_Database;
GO
-- Lưu lời nhắn từ checkout để nhân viên đọc được sau khi khách đặt đơn.
IF COL_LENGTH(N'dbo.Order', N'customer_note') IS NULL
    ALTER TABLE dbo.[Order] ADD customer_note nvarchar(500) NULL;
GO
