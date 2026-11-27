-- =============================================================================
-- KỊCH BẢN KIỂM THỬ HÀM allocate_fefo – dùng với supabase/seed.sql (seed của nhóm)
-- Cách chạy trong Supabase SQL Editor: bôi đen TỪNG CA (từ dòng "-- CA ..." đến hết ca), bấm Run, chụp kết quả.
-- Mỗi ca tự xoá đơn test cũ và đưa tồn kho các lô liên quan về số ban đầu của seed,
-- nên chạy lại bao nhiêu lần cũng được.
-- Lô dùng trong test (theo seed):
--   1 BATCH-20261124-RAU01  Cải thìa   HSD +3 ngày  tồn 120
--   8 BATCH-CAITHIA-SOLDOUT Cải thìa   HSD +1 ngày  tồn 0     (hết hàng)
--   4 TOM04                 Cà chua bi HSD +1 ngày  tồn 32
--   9 TOM05                 Cà chua bi HSD +6 ngày  tồn 50
--   7 LOL01                 Xà lách    HSD +2 ngày  tồn 18
--   3 CUC02                 Dưa leo    HSD −1 ngày  tồn 14.2  (quá hạn)
-- =============================================================================


-- CA 1: Chia một đơn qua 2 lô – mua 40 kg cà chua bi
-- Kỳ vọng: lấy hết 32 kg ở TOM04 (hết hạn sớm hơn) rồi 8 kg ở TOM05
DELETE FROM orders WHERE order_number = 'TEST-FEFO-01';
UPDATE batches SET current_quantity = 32, status = 'in_stock' WHERE id = 4;
UPDATE batches SET current_quantity = 50, status = 'in_stock' WHERE id = 9;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-01', '00000000-0000-0000-0000-000000000004', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 1800000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 2, 'Cà chua bi baby', 45000, 40 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-01'));

SELECT b.batch_code AS ma_lo, b.exp_date AS han_dung, od.quantity AS so_luong_lay,
       b.current_quantity AS ton_con_lai, b.status AS trang_thai_lo
FROM order_details od
JOIN order_items oi ON oi.id = od.order_item_id
JOIN orders o ON o.id = oi.order_id
JOIN batches b ON b.id = od.batch_id
WHERE o.order_number = 'TEST-FEFO-01'
ORDER BY b.exp_date;


-- CA 2: Bỏ qua lô hết hàng dù hết hạn sớm hơn – mua 3 túi cải thìa
-- Kỳ vọng: lấy 3 túi ở BATCH-20261124-RAU01; KHÔNG lấy BATCH-CAITHIA-SOLDOUT (HSD +1 ngày nhưng tồn 0)
DELETE FROM orders WHERE order_number = 'TEST-FEFO-02';
UPDATE batches SET current_quantity = 120, status = 'in_stock' WHERE id = 1;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-02', '00000000-0000-0000-0000-000000000004', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 114000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 1, 'Cải thìa hữu cơ', 38000, 3 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-02'));

SELECT b.batch_code AS ma_lo, b.exp_date AS han_dung, od.quantity AS so_luong_lay,
       b.current_quantity AS ton_con_lai, b.status AS trang_thai_lo
FROM order_details od
JOIN order_items oi ON oi.id = od.order_item_id
JOIN orders o ON o.id = oi.order_id
JOIN batches b ON b.id = od.batch_id
WHERE o.order_number = 'TEST-FEFO-02'
ORDER BY b.exp_date;


-- CA 3: Thiếu hàng – mua 20 kg xà lách khi kho hợp lệ chỉ có 18 kg
-- Kỳ vọng: báo lỗi đỏ 'Không đủ tồn kho khả dụng cho sản phẩm "Xà lách Lolo xanh" (thiếu 2.00 đơn vị)'
-- Supabase chạy cả ca trong một transaction nên khi lỗi, mọi thay đổi của ca tự huỷ.
DELETE FROM orders WHERE order_number = 'TEST-FEFO-03';
UPDATE batches SET current_quantity = 18, status = 'in_stock' WHERE id = 7;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-03', '00000000-0000-0000-0000-000000000004', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 800000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 3, 'Xà lách Lolo xanh', 40000, 20 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-03'));


-- CA 3b (chạy NGAY SAU CA 3): chứng minh đã rollback – LOL01 vẫn 18 kg, không còn đơn TEST-FEFO-03
SELECT b.batch_code AS ma_lo, b.current_quantity AS ton_kho,
       (SELECT COUNT(*) FROM orders WHERE order_number = 'TEST-FEFO-03') AS so_don_test_con_lai
FROM batches b WHERE b.id = 7;


-- CA 4: Bỏ qua lô quá hạn – mua 1 kg dưa leo (chỉ có lô CUC02 đã quá hạn, còn 14.2 kg)
-- Kỳ vọng: báo lỗi đỏ 'Không đủ tồn kho khả dụng cho sản phẩm "Dưa leo baby giòn" (thiếu 1.00 đơn vị)'
DELETE FROM orders WHERE order_number = 'TEST-FEFO-04';

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-04', '00000000-0000-0000-0000-000000000004', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 32000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 4, 'Dưa leo baby giòn', 32000, 1 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-04'));


-- CA 5: Trigger toàn vẹn – ghi nhầm lô cà chua TOM04 vào dòng hàng cải thìa
-- Kỳ vọng: báo lỗi đỏ 'Toàn vẹn dữ liệu: Lô hàng (4) không thuộc sản phẩm của dòng đơn hàng (...)'
DELETE FROM orders WHERE order_number = 'TEST-FEFO-05';

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-05', '00000000-0000-0000-0000-000000000004', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 38000)
    RETURNING id
), oi AS (
    INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
    SELECT id, 1, 'Cải thìa hữu cơ', 38000, 1 FROM o
    RETURNING id
)
INSERT INTO order_details (order_item_id, batch_id, quantity)
SELECT id, 4, 1 FROM oi;
