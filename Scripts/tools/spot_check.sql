SET NOCOUNT ON;
PRINT '=== Review 1 ===';
SELECT 'DEV' AS src, CAST(comment AS nvarchar(200)) AS comment FROM SHOP_PET_Database.dbo.Review WHERE review_id=1
UNION ALL SELECT 'TGT', CAST(comment AS nvarchar(200)) FROM SHOP_PET_VERIFY.dbo.Review WHERE review_id=1;
PRINT '=== BoardingRoom 107 len ===';
SELECT 'DEV' AS src, LEN(description) AS l, DATALENGTH(description) AS dl FROM SHOP_PET_Database.dbo.BoardingRoom WHERE room_id=107
UNION ALL SELECT 'TGT', LEN(description), DATALENGTH(description) FROM SHOP_PET_VERIFY.dbo.BoardingRoom WHERE room_id=107;
PRINT '=== Booking 1377 / 1399 ===';
SELECT 'DEV' AS src, CAST(status AS nvarchar(40)) AS st, CAST(updated_at AS nvarchar(30)) AS u FROM SHOP_PET_Database.dbo.Booking WHERE booking_id IN (1377,1399)
UNION ALL SELECT 'TGT', CAST(status AS nvarchar(40)), CAST(updated_at AS nvarchar(30)) FROM SHOP_PET_VERIFY.dbo.Booking WHERE booking_id IN (1377,1399);
PRINT '=== Order 1973124218 (>=25/10) ===';
SELECT 'DEV' AS src, CAST(status AS nvarchar(40)) AS st, CAST(total_amount AS nvarchar(20)) AS amt FROM SHOP_PET_Database.dbo.[Order] WHERE order_id=1973124218
UNION ALL SELECT 'TGT', CAST(status AS nvarchar(40)), CAST(total_amount AS nvarchar(20)) FROM SHOP_PET_VERIFY.dbo.[Order] WHERE order_id=1973124218;
