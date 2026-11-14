-- ============================================================
--  DU LIEU DELTA (AN TOAN) - KHONG XOA DONG DU LIEU NAO
--  Chi them dong moi + cap nhat dong da ton tai.
--  Chay: sqlcmd -d SHOP_PET_Database -f 65001 -i db_sync_full.sql
-- ============================================================
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 49)
   AND NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 61)
BEGIN
    PRINT '  - xoa Customer 49 (trung email voi Customer 61)';
    DELETE FROM dbo.Customer WHERE customer_id = 49;
END
GO

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

-- ===== ChatMessages : 1 dong cap nhat =====
UPDATE dbo.[ChatMessages]
   SET         [Message] = N'chat
chat'
 WHERE [MessageID] = 1017;

COMMIT TRANSACTION;
GO
