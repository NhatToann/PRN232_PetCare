SET NOCOUNT ON;
DECLARE @i int = 1, @name nvarchar(100), @key nvarchar(100);
DECLARE @cols nvarchar(max), @sql nvarchar(max);
DECLARE @devdb nvarchar(200) = N'SHOP_PET_Database';
DECLARE @testdb nvarchar(200) = N'SHOP_PET_TEAMTEST';   -- <-- đổi tên DB cần so sánh

DECLARE @tables TABLE (id int identity, name nvarchar(100));
INSERT INTO @tables (name) VALUES
 ('Supplier'),('ProductCategory'),('Species'),('Breed'),('admin'),('Staff'),('Doctor'),
 ('PetService'),('Products'),('BreedPricing'),('Customer'),('Pet'),
 ('Order'),('Order_Detail'),('Payment'),('Booking'),('Booking_Service'),('Review'),
 ('ChatMessages'),('Cart'),('AttendanceRecords'),('MedicalRecord'),('Shifts'),
 ('ShiftRequests'),('WorkSchedule'),('StaffSalary'),('PayrollRecords'),
 ('boarding_bookings'),('BoardingRoom'),('SystemSettings');

WHILE @i <= (SELECT COUNT(*) FROM @tables)
BEGIN
    SELECT @name = name FROM @tables WHERE id = @i;
    SELECT @cols = STRING_AGG(QUOTENAME(c.name), ',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c WHERE c.object_id = OBJECT_ID(@devdb + '.dbo.' + @name);
    IF @cols IS NOT NULL
    BEGIN
        DECLARE @qn nvarchar(200) = QUOTENAME(@name);
        SET @sql = N'
        SELECT @m = (SELECT COUNT(*) FROM (SELECT ' + @cols + ' FROM ' + @devdb + '.dbo.' + @qn + '
                     EXCEPT SELECT ' + @cols + ' FROM ' + @testdb + '.dbo.' + @qn + ') a),
                    @e = (SELECT COUNT(*) FROM (SELECT ' + @cols + ' FROM ' + @testdb + '.dbo.' + @qn + '
                     EXCEPT SELECT ' + @cols + ' FROM ' + @devdb + '.dbo.' + @qn + ') b);';
        DECLARE @m int, @e int;
        EXEC sp_executesql @sql, N'@m int OUTPUT, @e int OUTPUT', @m = @m OUTPUT, @e = @e OUTPUT;
        IF @m > 0 OR @e > 0
            PRINT @name + ' | thieu=' + CAST(@m AS nvarchar(10)) + ' | thua=' + CAST(@e AS nvarchar(10));
    END
    SET @i += 1;
END
PRINT '--- xong ---';
