-- =============================================================================
-- KỊCH BẢN KIỂM THỬ HÀM allocate_fefo – dùng trong Supabase SQL Editor
-- Yêu cầu: đã chạy fix_allocate_fefo.sql và seed.sql.
-- Cách chạy: bôi đen TỪNG CA (từ dòng "-- CA ..." đến hết ca), bấm Run, chụp kết quả.
-- Mỗi ca tự dọn đơn test cũ và đưa tồn kho các lô liên quan về số ban đầu,
-- nên chạy lại bao nhiêu lần cũng được, theo thứ tự nào cũng được.
-- =============================================================================


-- CA 1: Đúng ví dụ của đề – mua 10 kg cà chua
-- Kỳ vọng: lấy 3 kg ở BATCH-CACHUA-01 (cận hạn) rồi 7 kg ở BATCH-CACHUA-02
DELETE FROM orders WHERE order_number = 'TEST-FEFO-01';
UPDATE batches SET current_quantity = 3,  status = 'in_stock' WHERE id = 5;
UPDATE batches SET current_quantity = 50, status = 'in_stock' WHERE id = 6;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-01', '00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ, TP.HCM', 450000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 2, 'Cà chua bi baby', 45000, 10 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-01'));

SELECT b.batch_code AS ma_lo, b.exp_date AS han_dung, od.quantity AS so_luong_lay,
       b.current_quantity AS ton_con_lai, b.status AS trang_thai_lo
FROM order_details od
JOIN order_items oi ON oi.id = od.order_item_id
JOIN orders o ON o.id = oi.order_id
JOIN batches b ON b.id = od.batch_id
WHERE o.order_number = 'TEST-FEFO-01'
ORDER BY b.exp_date;


-- CA 2: Bỏ qua lô quá hạn, lô hết hàng, lô đang trồng – mua 10 kg cải thìa
-- Kỳ vọng: 3 kg ở BATCH-CAITHIA-01, 7 kg ở BATCH-CAITHIA-02;
-- KHÔNG xuất hiện BATCH-CAITHIA-EXPIRED, BATCH-CAITHIA-SOLDOUT, BATCH-CAITHIA-GROWING
DELETE FROM orders WHERE order_number = 'TEST-FEFO-02';
UPDATE batches SET current_quantity = 3,  status = 'in_stock' WHERE id = 1;
UPDATE batches SET current_quantity = 25, status = 'in_stock' WHERE id = 2;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-02', '00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ, TP.HCM', 350000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 1, 'Cải thìa hữu cơ', 35000, 10 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-02'));

SELECT b.batch_code AS ma_lo, b.exp_date AS han_dung, od.quantity AS so_luong_lay,
       b.current_quantity AS ton_con_lai, b.status AS trang_thai_lo
FROM order_details od
JOIN order_items oi ON oi.id = od.order_item_id
JOIN orders o ON o.id = oi.order_id
JOIN batches b ON b.id = od.batch_id
WHERE o.order_number = 'TEST-FEFO-02'
ORDER BY b.exp_date;


-- CA 3: Thiếu hàng – đúng ví dụ của đề "tổng kho hợp lệ chỉ có 8 kg"
-- Xà lách có 5 kg + 3 kg = 8 kg, đặt 10 kg
-- Kỳ vọng: báo lỗi đỏ 'Không đủ tồn kho khả dụng cho sản phẩm "Xà lách Lolo xanh" (thiếu 2.00 đơn vị)'
-- Supabase chạy cả ca trong một transaction nên khi lỗi, mọi thay đổi của ca này tự huỷ.
DELETE FROM orders WHERE order_number = 'TEST-FEFO-03';
UPDATE batches SET current_quantity = 5, status = 'in_stock' WHERE id = 7;
UPDATE batches SET current_quantity = 3, status = 'in_stock' WHERE id = 8;

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-03', '00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ, TP.HCM', 400000)
    RETURNING id
)
INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
SELECT id, 3, 'Xà lách Lolo xanh', 40000, 10 FROM o;

SELECT allocate_fefo((SELECT id FROM orders WHERE order_number = 'TEST-FEFO-03'));


-- CA 3b (chạy NGAY SAU CA 3): chứng minh đã rollback – kho xà lách không đổi, không có đơn TEST-FEFO-03
SELECT b.batch_code AS ma_lo, b.current_quantity AS ton_kho,
       (SELECT COUNT(*) FROM orders WHERE order_number = 'TEST-FEFO-03') AS so_don_test_con_lai
FROM batches b WHERE b.id IN (7, 8) ORDER BY b.id;


-- CA 4: Trigger toàn vẹn – ghi nhầm lô cà chua (lô 5) vào dòng hàng cải thìa
-- Kỳ vọng: báo lỗi đỏ 'Toàn vẹn dữ liệu: Lô hàng (5) không thuộc sản phẩm của dòng đơn hàng (...)'
DELETE FROM orders WHERE order_number = 'TEST-FEFO-04';

WITH o AS (
    INSERT INTO orders (order_number, customer_id, customer_name, customer_phone, shipping_address, total_amount)
    VALUES ('TEST-FEFO-04', '00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ, TP.HCM', 35000)
    RETURNING id
), oi AS (
    INSERT INTO order_items (order_id, product_id, product_name, unit_price, quantity)
    SELECT id, 1, 'Cải thìa hữu cơ', 35000, 1 FROM o
    RETURNING id
)
INSERT INTO order_details (order_item_id, batch_id, quantity)
SELECT id, 5, 1 FROM oi;
