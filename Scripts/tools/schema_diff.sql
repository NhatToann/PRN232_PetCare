SET NOCOUNT ON;

PRINT '=== COLUMNS: only in DEV ===';
SELECT t.name + '.' + c.name AS cot, ty.name AS kieu, c.max_length, c.is_nullable
FROM SHOP_PET_Database.sys.tables t
JOIN SHOP_PET_Database.sys.columns c ON c.object_id=t.object_id
JOIN SHOP_PET_Database.sys.types ty ON ty.user_type_id=c.user_type_id
WHERE NOT EXISTS (
  SELECT 1 FROM SHOP_PET_TEAMOLD.sys.columns oc
  WHERE oc.object_id = OBJECT_ID('SHOP_PET_TEAMOLD.dbo.' + t.name) AND oc.name = c.name)
ORDER BY t.name, c.column_id;

PRINT '=== COLUMNS: only in OLD ===';
SELECT t.name + '.' + c.name AS cot
FROM SHOP_PET_TEAMOLD.sys.tables t
JOIN SHOP_PET_TEAMOLD.sys.columns c ON c.object_id=t.object_id
WHERE NOT EXISTS (
  SELECT 1 FROM SHOP_PET_Database.sys.columns dc
  WHERE dc.object_id = OBJECT_ID('SHOP_PET_Database.dbo.' + t.name) AND dc.name = c.name)
ORDER BY t.name, c.column_id;

PRINT '=== CHECK CONSTRAINTS: only in DEV ===';
SELECT OBJECT_NAME(parent_object_id) + '.' + name AS ck, definition
FROM SHOP_PET_Database.sys.check_constraints
WHERE NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.check_constraints oc
                  WHERE oc.name = check_constraints.name AND oc.parent_object_id = check_constraints.parent_object_id)
ORDER BY 1;

PRINT '=== FOREIGN KEYS: only in DEV ===';
SELECT OBJECT_NAME(parent_object_id) + '.' + name AS fk
FROM SHOP_PET_Database.sys.foreign_keys
WHERE NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.foreign_keys ofk WHERE ofk.name = foreign_keys.name)
ORDER BY 1;

PRINT '=== UNIQUE INDEXES: only in DEV ===';
SELECT OBJECT_NAME(i.object_id) + '.' + i.name AS idx
FROM SHOP_PET_Database.sys.indexes i
WHERE i.is_unique=1 AND i.is_primary_key=0 AND i.type>0
  AND NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.indexes oi
                  WHERE oi.object_id=i.object_id AND oi.name=i.name
                    AND oi.index_id=i.index_id)
ORDER BY 1;

PRINT '=== PROCEDURES: only in DEV ===';
SELECT name FROM SHOP_PET_Database.sys.objects WHERE type='P'
  AND NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.objects o WHERE o.type='P' AND o.name=objects.name)
ORDER BY name;

PRINT '=== TRIGGERS: only in DEV ===';
SELECT name FROM SHOP_PET_Database.sys.objects WHERE type='TR'
  AND NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.objects o WHERE o.type='TR' AND o.name=objects.name)
ORDER BY name;

PRINT '=== VIEWS: only in DEV ===';
SELECT name FROM SHOP_PET_Database.sys.objects WHERE type='V'
  AND NOT EXISTS (SELECT 1 FROM SHOP_PET_TEAMOLD.sys.objects o WHERE o.type='V' AND o.name=objects.name)
ORDER BY name;
