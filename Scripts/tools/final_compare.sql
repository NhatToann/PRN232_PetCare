SET NOCOUNT ON;
DECLARE @dev sysname='SHOP_PET_Database', @tgt sysname='SHOP_PET_VERIFY';
DECLARE @sql nvarchar(max);
DECLARE @tabs TABLE(ord int identity(1,1), t sysname, pk sysname, idc sysname);
INSERT INTO @tabs(t,pk,idc) VALUES
 ('Supplier','supplier_id','supplier_id'),('Products','product_id','product_id'),
 ('PetService','service_id','service_id'),('Customer','customer_id','customer_id'),
 ('Pet','id','id'),('Order','order_id','order_id'),('Order_Detail','detail_id','detail_id'),
 ('Payment','payment_id','payment_id'),('Booking','booking_id','booking_id'),
 ('Booking_Service','booking_service_id','booking_service_id'),('Review','review_id','review_id'),
 ('ChatMessages','MessageID','MessageID'),('Staff','staff_id','staff_id'),
 ('Doctor','doctor_id','doctor_id'),('BreedPricing','breed_pricing_id','breed_pricing_id'),
 ('BoardingRoom','room_id','room_id'),('SystemSettings','SettingKey','SettingKey');
DECLARE @i int=1;
PRINT '=== MISSING IN TARGET (co o dev, thieu o target) ===';
WHILE @i<=(SELECT MAX(ord) FROM @tabs)
BEGIN
 DECLARE @t sysname,@pk sysname,@idc sysname;
 SELECT @t=t,@pk=pk,@idc=idc FROM @tabs WHERE ord=@i;
 SET @sql=N'SELECT '''+@t+''' AS t, CAST(d.'+QUOTENAME(@idc)+N' AS NVARCHAR(60)) AS id FROM '+QUOTENAME(@dev)+N'.dbo.'+QUOTENAME(@t)+N' d
 WHERE NOT EXISTS (SELECT 1 FROM '+QUOTENAME(@tgt)+N'.dbo.'+QUOTENAME(@t)+N' s WHERE s.'+QUOTENAME(@pk)+N'=d.'+QUOTENAME(@idc)+N');';
 EXEC sp_executesql @sql;
 SET @i+=1;
END
PRINT '=== EXTRA IN TARGET (khong co o dev) ===';
SET @i=1;
WHILE @i<=(SELECT MAX(ord) FROM @tabs)
BEGIN
 DECLARE @t2 sysname,@pk2 sysname,@idc2 sysname;
 SELECT @t2=t,@pk2=pk,@idc2=idc FROM @tabs WHERE ord=@i;
 SET @sql=N'SELECT '''+@t2+''' AS t, CAST(s.'+QUOTENAME(@idc2)+N' AS NVARCHAR(60)) AS id FROM '+QUOTENAME(@tgt)+N'.dbo.'+QUOTENAME(@t2)+N' s
 WHERE NOT EXISTS (SELECT 1 FROM '+QUOTENAME(@dev)+N'.dbo.'+QUOTENAME(@t2)+N' d WHERE d.'+QUOTENAME(@idc2)+N'=s.'+QUOTENAME(@idc2)+N');';
 EXEC sp_executesql @sql;
 SET @i+=1;
END
PRINT '=== VALUE DIFF ===';
SET @i=1;
WHILE @i<=(SELECT MAX(ord) FROM @tabs)
BEGIN
 DECLARE @t3 sysname,@pk3 sysname,@idc3 sysname;
 SELECT @t3=t,@pk3=pk,@idc3=idc FROM @tabs WHERE ord=@i;
 DECLARE @cmp nvarchar(max)=N'';
 SELECT @cmp=@cmp+N' OR ISNULL(CAST(s.'+QUOTENAME(c.name)+N' AS NVARCHAR(MAX)),CHAR(1))<>ISNULL(CAST(d.'+QUOTENAME(c.name)+N' AS NVARCHAR(MAX)),CHAR(1))'
 FROM SHOP_PET_Database.sys.columns c
 WHERE c.object_id=OBJECT_ID('SHOP_PET_Database.dbo.'+@t3) AND c.name NOT IN (@pk3,@idc3);
 IF LEN(@cmp)>10
 BEGIN
  SET @sql=N'SELECT '''+@t3+''' AS t, CAST(d.'+QUOTENAME(@idc3)+N' AS NVARCHAR(60)) AS id FROM '+QUOTENAME(@dev)+N'.dbo.'+QUOTENAME(@t3)+N' d
 JOIN '+QUOTENAME(@tgt)+N'.dbo.'+QUOTENAME(@t3)+N' s ON s.'+QUOTENAME(@pk3)+N'=d.'+QUOTENAME(@idc3)+N' WHERE '+STUFF(@cmp,1,3,N'')+N';';
  EXEC sp_executesql @sql;
 END
 SET @i+=1;
END
