import io, os, re

root = r"D:\1_F_Matierials\Kỳ 8\1_PRN232\New folder\PRN232_PetCareProject"
enc = "utf-8"

a = io.open(os.path.join(root, "Scripts", "2026-11-14_sync_team.sql"), encoding=enc).read()
b = io.open(os.path.join(root, "Scripts", "tools", "_delta_old_safe.sql"), encoding=enc).read()

# --- schema block: from "PRINT '=== [1]" up to "PRINT '=== [5]" ---
i1 = a.index("PRINT '=== [1]")
i5 = a.index("PRINT '=== [5]")
assert i1 > 0 and i5 > i1, (i1, i5)
schema_block = a[i1:i5].rstrip()

# --- data block: tu phan xoa Customer 49 den COMMIT TRANSACTION ---
j0 = b.index("IF EXISTS (SELECT 1 FROM dbo.Customer WHERE customer_id = 49)")
j1 = b.index("-- ===== Supplier")
j2 = b.rindex("COMMIT TRANSACTION;")
data_block = ("BEGIN TRANSACTION;\n" + b[j0:j1].rstrip() + "\n" +
              b[j1:j2].rstrip() + "\nCOMMIT TRANSACTION;")

header = """/* =====================================================================
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
              -f 65001 -i Scripts\\2026-11-15_quick_sync_from_2026-10-25.sql

   * BAT BUOC co -f 65001, neu khong tieng Viet se bi hong.
   * Script KHONG dung "USE [SHOP_PET_Database]" nen -d la bat buoc.
   * Idempotent: chay lai nhieu lan van cho ket qua giong nhau.
   * KHONG xoa du lieu cu. Chi xoa duy nhat Customer 49 (trung email voi
     Customer 61 moi tao) de khong vi pham UNIQUE(UX_Customer_Email).
   ===================================================================== */

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

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

"""

data_header = """/* =====================================================================
   PHAN 4 - DU LIEU PHAT SINH TU 25/10/2026
   -----------------------------------------------------------------
   Cac dong moi (INSERT) va cac dong da bi sua (UPDATE) so voi DB dev.
   Thu tu: cha truoc, con sau. Moi INSERT deu co dieu kien NOT EXISTS
   nen chay lai nhieu lan khong bi trung du lieu.
   ===================================================================== */
PRINT '=== [4] DU LIEU TU 25/10/2026 ===';
GO

"""

footer = """
GO

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
"""

out = header + schema_block + "\r\nGO\r\n" + data_header + data_block + "\r\n" + footer

# them SET QUOTED_IDENTIFIER / ANSI_NULLS sau moi GO (GO ve mac dinh client)
out = re.sub(r"(?m)^GO[ \t]*$",
             "GO\nSET QUOTED_IDENTIFIER ON;\nSET ANSI_NULLS ON;\nSET NOCOUNT ON;",
             out)

path = os.path.join(root, "Scripts", "2026-11-15_quick_sync_from_2026-10-25.sql")
io.open(path, "w", encoding=enc, newline="").write(out)
print("written ok", len(out))
