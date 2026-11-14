USE [SHOP_PET_Database];
GO
-- Bản SQL cũ chưa có hai trường hồ sơ mà model hiện tại đã sử dụng.
IF COL_LENGTH(N'dbo.Customer', N'avatar_url') IS NULL
    ALTER TABLE dbo.Customer ADD avatar_url nvarchar(500) NULL;
IF COL_LENGTH(N'dbo.Customer', N'birth_date') IS NULL
    ALTER TABLE dbo.Customer ADD birth_date date NULL;
GO
