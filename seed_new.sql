-- =============================================================================
-- DỮ LIỆU MẪU CHUẨN PRODUCTION / STAGING CHO HỆ THỐNG FARMLY (SEED DATA)
-- Khớp 100% với 24 bảng CSDL PostgreSQL & giao diện Frontend
-- =============================================================================

-- 1. TÀI KHOẢN NGƯỜI DÙNG: ĐÚNG 4 VAI TRÒ (1 Admin, 1 Farm Staff, 1 Sales, 1 Customer)
-- Mật khẩu đăng nhập test trên Supabase Auth: Farmly@123
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_users RECORD;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'auth' AND table_name = 'users') THEN
        FOR v_users IN
            SELECT * FROM (VALUES
                ('00000000-0000-0000-0000-000000000001'::uuid, 'admin@farmly.vn',      'Nguyễn Quốc Bảo (Admin)',   'admin'),
                ('00000000-0000-0000-0000-000000000002'::uuid, 'thuan.tran@farmly.vn', 'Trần Văn Thuận (#402)',     'farm_staff'),
                ('00000000-0000-0000-0000-000000000003'::uuid, 'ngoc.sales@farmly.vn', 'Lê Bảo Ngọc (Sales/CSKH)',  'sales'),
                ('00000000-0000-0000-0000-000000000004'::uuid, 'minhanh@gmail.com',    'Minh Anh',                  'customer')
            ) AS t(id, email, full_name, role)
        LOOP
            IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = v_users.email) THEN
                INSERT INTO auth.users (
                    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                    confirmation_token, recovery_token, email_change_token_new, email_change
                ) VALUES (
                    v_users.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                    v_users.email, crypt('Farmly@123', gen_salt('bf')), NOW(),
                    '{"provider":"email","providers":["email"]}',
                    jsonb_build_object('full_name', v_users.full_name, 'role', v_users.role),
                    NOW(), NOW(), '', '', '', ''
                ) ON CONFLICT (id) DO NOTHING;

                INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
                VALUES (
                    gen_random_uuid(), v_users.id, v_users.id::text,
                    jsonb_build_object('sub', v_users.id::text, 'email', v_users.email), 'email', NOW(), NOW(), NOW()
                ) ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;
END $$;

INSERT INTO profiles (id, email, full_name, phone, avatar_url, role) VALUES
('00000000-0000-0000-0000-000000000001', 'admin@farmly.vn',      'Nguyễn Quốc Bảo (Admin)',  '0901234567', 'https://api.dicebear.com/7.x/initials/svg?seed=QB', 'admin'),
('00000000-0000-0000-0000-000000000002', 'thuan.tran@farmly.vn', 'Trần Văn Thuận (#402)',    '0902345678', 'https://api.dicebear.com/7.x/initials/svg?seed=TT', 'farm_staff'),
('00000000-0000-0000-0000-000000000003', 'ngoc.sales@farmly.vn', 'Lê Bảo Ngọc (Sales/CSKH)', '0903456789', 'https://api.dicebear.com/7.x/initials/svg?seed=BN', 'sales'),
('00000000-0000-0000-0000-000000000004', 'minhanh@gmail.com',    'Minh Anh',                 '0909876543', 'https://api.dicebear.com/7.x/initials/svg?seed=MA', 'customer')
ON CONFLICT (email) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    phone = EXCLUDED.phone,
    role = EXCLUDED.role;

-- Địa chỉ giao hàng mặc định của khách hàng duy nhất
INSERT INTO addresses (id, user_id, recipient_name, phone, address_line, ward, province, is_default) VALUES
(1, (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), 'Minh Anh', '0909876543', '123 Đường Nguyễn Huệ', 'Phường Bến Nghé, Quận 1', 'TP. Hồ Chí Minh', true)
ON CONFLICT (id) DO NOTHING;

-- 2. CẤU HÌNH HỆ THỐNG (SETTINGS)
INSERT INTO settings (key, value) VALUES
('farm_name', 'Farmly Organic Farm - Vườn Thượng Lạc Dương & Củ Chi'),
('default_warehouse', 'Kho 04 - Đà Lạt'),
('warning_days_before_expiry', '2'),
('cold_chain_min_temp', '2.0'),
('cold_chain_max_temp', '5.0'),
('farm_lat', '10.9805'),
('farm_lng', '106.5050'),
('shipping_fee_per_km', '5000'),
('min_shipping_fee', '15000'),
('support_email', 'support@farmlyorganic.com')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- 3. DANH MỤC NÔNG SẢN
INSERT INTO categories (id, name, slug, description, image_url, allow_subscription, is_active) VALUES
(1, 'Rau ăn lá', 'rau-an-la', 'Rau xanh hữu cơ thu hoạch lúc 05:15 sáng, giao lạnh trong 6 giờ.', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600', true, true),
(2, 'Củ quả tươi', 'cu-qua-tuoi', 'Cà chua, dưa leo, cà rốt canh tác đất đỏ bazan chuẩn VietGAP.', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600', true, true),
(3, 'Nấm & Thảo mộc', 'nam-thao-moc', 'Nấm sạch nuôi trồng vô trùng và rau gia vị hữu cơ.', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600', false, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

-- 4. SẢN PHẨM NÔNG SẢN
INSERT INTO products (id, category_id, name, slug, unit, base_price, short_description, description, preservation_days, is_active) VALUES
(1, 1, 'Cải thìa hữu cơ', 'cai-thia-huu-co', 'Túi 500g', 38000, 'Cải thìa chuẩn vi sinh hữu cơ, bẹ dày, giòn ngọt tự nhiên.', 'Trồng tại Nhà kính A1 trên nền đất đỏ bazan giàu khoáng chất. Tưới nước suối ngầm Lang Biang (TDS 42 ppm) và kiểm tra trắng 64 chỉ tiêu BVTV trước thu hoạch.', 3, true),
(2, 2, 'Cà chua bi baby', 'ca-chua-bi-baby', 'kg', 45000, 'Cà chua bi Hà Lan mọng nước, vị ngọt thanh giàu vitamin C.', 'Thụ phấn tự nhiên bằng ong bầu, chín cây 100%, không chất kích thích tăng trưởng.', 8, true),
(3, 1, 'Xà lách Lolo xanh', 'xa-lach-lolo-xanh', 'kg', 40000, 'Xà lách thủy canh tuần hoàn giòn ngọt, lá xoăn đẹp.', 'Canh tác thủy canh khép kín không đất, sạch tuyệt đối dư lượng kim loại nặng.', 4, true),
(4, 2, 'Dưa leo baby giòn', 'dua-chuot-baby-gion', 'kg', 32000, 'Dưa chuột quả nhỏ đặc ruột, không đắng, ăn trực tiếp giòn tan.', 'Thu hái non mỗi sáng sớm, bảo quản chuỗi lạnh 3.6°C giữ trọn độ giòn.', 5, true),
(5, 2, 'Cà rốt Đà Lạt', 'ca-rot-da-lat', 'kg', 28000, 'Cà rốt củ đều, vị ngọt đậm, giàu Beta-Carotene tự nhiên.', 'Trồng luân canh trên đất đỏ bazan tơi xốp với phân trùn quế hữu cơ.', 10, true),
(6, 1, 'Rau mầm organic', 'rau-mam-organic', 'Túi 250g', 20000, 'Rau mầm cải củ non mướt, giàu enzyme và chất chống oxy hóa.', 'Ươm trên giá thể xơ dừa sạch vô trùng trong 7 ngày, không phân bón hóa học.', 4, true),
(7, 1, 'Rau muống nước hữu cơ', 'rau-muong-nuoc-huu-co', 'kg', 28000, 'Rau muống ngọn non mướt, cọng giòn xào tỏi thơm ngon.', 'Canh tác vùng đệm sinh học Củ Chi, kiểm định nguồn nước đầu vào hàng tuần.', 3, true),
(8, 3, 'Nấm đùi gà tươi', 'nam-dui-ga-tuoi', 'kg', 65000, 'Nấm đùi gà nuôi trồng nhà lạnh vô trùng, thân chắc ngọt thịt.', 'Nuôi trồng trên mùn cưa cao su thanh trùng hơi nước, không chất bảo quản.', 7, true)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    unit = EXCLUDED.unit,
    base_price = EXCLUDED.base_price,
    short_description = EXCLUDED.short_description;

-- Ảnh sản phẩm (Ảnh local đúng từng loại + URL Unsplash đã kiểm chứng 200 OK)
INSERT INTO product_images (id, product_id, image_url, is_primary, display_order) VALUES
(1, 1, '/images/bok-choy.jpg', true, 1),
(2, 1, 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=800', false, 2),
(3, 2, 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800', true, 1),
(4, 3, 'https://images.unsplash.com/photo-1556801712-76c8eb07bbc9?w=800', true, 1),
(5, 4, 'https://images.unsplash.com/photo-1604977042946-1eecc30f269e?w=800', true, 1),
(6, 5, '/images/carrot.jpg', true, 1),
(7, 6, '/images/microgreens.jpg', true, 1),
(8, 7, '/images/water-spinach.jpg', true, 1),
(9, 8, '/images/king-oyster-mushroom.jpg', true, 1)
ON CONFLICT (id) DO NOTHING;

-- Chứng nhận chất lượng & Kiểm định VietGAP
INSERT INTO quality_certifications (id, product_id, cert_name, cert_number, issued_by, issue_date, expiry_date, file_url) VALUES
(1, 1, 'VietGAP Trồng Trọt & Test 64 Chỉ Tiêu BVTV', 'VG-2026-LD01', 'Trung tâm Phân tích & Kiểm định Nông nghiệp Lâm Đồng', '2026-01-15', '2027-01-15', 'https://farmly.vn/certs/vietgap-rau01.pdf'),
(2, 2, 'GlobalGAP & USDA Organic Standard', 'GG-VN-2026-99', 'Control Union Certifications', '2026-02-10', '2027-02-10', 'https://farmly.vn/certs/globalgap-tom04.pdf'),
(3, 3, 'VietGAP Thủy Canh Tuần Hoàn', 'VG-2026-HC03', 'Chi cục Trồng trọt & BVTV TP.HCM', '2026-03-01', '2027-03-01', 'https://farmly.vn/certs/vietgap-lolo03.pdf')
ON CONFLICT (id) DO NOTHING;

-- 5. LÔ HÀNG (BATCHES) - KHỚP 100% VỚI GIAO DIỆN FARM STAFF & FEFO
-- Lưu ý: Để disposed_quantity = 0.00 ở đây vì mục (7) INSERT vào inventory_disposals
-- sẽ tự động kích hoạt trigger_inventory_disposal trừ tồn kho thực tế!
INSERT INTO batches (id, batch_code, product_id, sowing_date, harvest_date, exp_date, initial_quantity, current_quantity, disposed_quantity, qr_code, qr_scan_count, status, flash_sale_price) VALUES
-- Lô 1: Cải thìa RAU01 (khởi tạo 122.00 -> sau trigger xuất hủy 2.00 ở mục 7 sẽ còn đúng 120.00)
(1, 'BATCH-20261124-RAU01', 1, CURRENT_DATE - INTERVAL '32 days', CURRENT_DATE, CURRENT_DATE + INTERVAL '3 days', 320.00, 122.00, 0.00, 'http://localhost:5173/truy-xuat/BATCH-20261124-RAU01', 148, 'in_stock', NULL),
-- Lô 2: Cải thìa RAU02 (nhập sau, HSD xa hơn)
(2, 'RAU02', 1, CURRENT_DATE - INTERVAL '28 days', CURRENT_DATE, CURRENT_DATE + INTERVAL '4 days', 100.00, 85.00, 0.00, 'http://localhost:5173/truy-xuat/RAU02', 12, 'in_stock', NULL),
-- Lô 3: Dưa leo baby CUC02 (quá hạn -> FEFO phải bỏ qua, Staff cần xuất hủy)
(3, 'CUC02', 4, CURRENT_DATE - INTERVAL '40 days', CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE - INTERVAL '1 day', 50.00, 14.20, 0.00, 'http://localhost:5173/truy-xuat/CUC02', 19, 'in_stock', NULL),
-- Lô 4: Cà chua bi TOM04 (khởi tạo 34.00 -> sau trigger xuất hủy 2.00 ở mục 7 sẽ còn đúng 32.00, cận hạn <= 48h)
(4, 'TOM04', 2, CURRENT_DATE - INTERVAL '55 days', CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '1 day', 60.00, 34.00, 0.00, 'http://localhost:5173/truy-xuat/TOM04', 45, 'in_stock', 35000),
-- Lô 5: Cà rốt Đà Lạt CAR03
(5, 'CAR03', 5, CURRENT_DATE - INTERVAL '70 days', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '6 days', 60.00, 40.00, 0.00, 'http://localhost:5173/truy-xuat/CAR03', 27, 'in_stock', NULL),
-- Lô 6: Rau mầm organic MAM01
(6, 'MAM01', 6, CURRENT_DATE - INTERVAL '9 days', CURRENT_DATE, CURRENT_DATE + INTERVAL '4 days', 25.00, 12.00, 0.00, 'http://localhost:5173/truy-xuat/MAM01', 31, 'in_stock', NULL),
-- Lô 7: Xà lách Lolo xanh LOL01 (cận hạn -> Flash Sale)
(7, 'LOL01', 3, CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '2 days', 45.00, 18.00, 0.00, 'http://localhost:5173/truy-xuat/LOL01', 22, 'in_stock', 32000),
-- Lô 8: Lô đã bán hết (dùng test FEFO bỏ qua lô hết hàng)
(8, 'BATCH-CAITHIA-SOLDOUT', 1, CURRENT_DATE - INTERVAL '45 days', CURRENT_DATE - INTERVAL '12 days', CURRENT_DATE + INTERVAL '1 day', 40.00, 0.00, 0.00, 'http://localhost:5173/truy-xuat/BATCH-CAITHIA-SOLDOUT', 64, 'sold_out', NULL)
ON CONFLICT (id) DO NOTHING;

-- 6. NHẬT KÝ CANH TÁC THỰC ĐỊA (FARMING LOGS) - 4 GIAI ĐOẠN CHO LÔ RAU01
INSERT INTO farming_logs (id, batch_id, performed_by, stage, title, description, evidence_image_url, logged_at) VALUES
(1, 1, (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), 'sowing', 'Gieo Hạt Non-GMO', 'Hạt thuần chủng không biến đổi gen, ươm vi sinh 4 ngày trong nhà kính A1.', '/images/seedling-tray.jpg', CURRENT_TIMESTAMP - INTERVAL '25 days'),
(2, 1, (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), 'fertilizing', 'Phân Trùn Quế Tự Nhiên', 'Bón lót trùn quế & men vi sinh EM bản địa, hoàn toàn không dùng đạm hóa học.', '/images/organic-soil.jpg', CURRENT_TIMESTAMP - INTERVAL '12 days'),
(3, 1, (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), 'watering', 'Tưới Nước Lang Biang', 'Hệ thống tưới phun sương suối ngầm tự nhiên. Chỉ số TDS đo được: 42 ppm.', 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=600', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(4, 1, (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), 'harvesting', 'Test 64 Chỉ Tiêu BVTV & Thu Hoạch', 'Kiểm tra ngẫu nhiên mẫu lá dư lượng thuốc BVTV đạt 0.00 ppm. Thu hái lúc 05:15 sáng.', '/images/lab-test.jpg', CURRENT_TIMESTAMP)
ON CONFLICT (id) DO NOTHING;

-- 7. PHIẾU XUẤT HỦY HÀNG HƯ HỎNG (INVENTORY DISPOSALS)
INSERT INTO inventory_disposals (id, batch_id, quantity_disposed, reason, note, image_url, disposed_by, created_at) VALUES
(1, 1, 1.50, 'damaged', 'Hướng xử lý: Ủ phân bón | Dập lá ngoài khi chuyển sọt vào kho lạnh', '/images/bok-choy.jpg', (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), CURRENT_TIMESTAMP - INTERVAL '2 hours'),
(2, 4, 2.00, 'damaged', 'Hướng xử lý: Bán giảm giá | Cà chua chín mềm, chuyển quầy Flash Sale trong ngày', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400', (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), CURRENT_TIMESTAMP - INTERVAL '4 hours'),
(3, 1, 0.50, 'damaged', 'Hướng xử lý: Ủ phân bón | Héo úa nhẹ phần ngọn do độ ẩm kho biến động', '/images/bok-choy.jpg', (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), CURRENT_TIMESTAMP - INTERVAL '5 hours')
ON CONFLICT (id) DO NOTHING;

-- 8. ĐƠN HÀNG MẪU, CHI TIẾT PHÂN BỔ FEFO & THANH TOÁN
INSERT INTO orders (id, order_number, customer_id, confirmed_by, order_type, status, customer_name, customer_phone, shipping_address, distance_km, shipping_fee, total_amount, customer_note, expected_delivery_date, delivered_at) VALUES
(1, 'ORD-20261124-001', (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), (SELECT id FROM profiles WHERE email = 'ngoc.sales@farmly.vn'), 'retail', 'delivered', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 8.50, 42500, 118500, 'Giao trước 11:30 sáng', CURRENT_DATE - INTERVAL '1 day', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(2, 'ORD-20261124-002', (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), (SELECT id FROM profiles WHERE email = 'ngoc.sales@farmly.vn'), 'retail', 'delivered', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 8.50, 35000, 125000, 'Để tại bảo vệ nếu không bắt máy', CURRENT_DATE - INTERVAL '2 days', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(3, 'ORD-20261124-003', (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), (SELECT id FROM profiles WHERE email = 'ngoc.sales@farmly.vn'), 'retail', 'delivered', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 8.50, 30000, 106000, 'Đóng gói túi giấy giữ lạnh', CURRENT_DATE - INTERVAL '4 days', CURRENT_TIMESTAMP - INTERVAL '4 days'),
(4, 'ORD-20261125-004', (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), NULL, 'retail', 'pending', 'Minh Anh', '0909876543', '123 Nguyễn Huệ, Quận 1, TP.HCM', 8.50, 42500, 156500, 'Đơn mới chờ Sales duyệt xuất kho FEFO', CURRENT_DATE, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO order_items (id, order_id, product_id, product_name, unit_price, quantity) VALUES
(1, 1, 1, 'Cải thìa hữu cơ', 38000, 2.00),
(2, 2, 2, 'Cà chua bi baby', 45000, 2.00),
(3, 3, 1, 'Cải thìa hữu cơ', 38000, 2.00),
(4, 4, 1, 'Cải thìa hữu cơ', 38000, 3.00)
ON CONFLICT (id) DO NOTHING;

-- Phân bổ lô FEFO cho các đơn đã xác nhận/giao
INSERT INTO order_details (id, order_item_id, batch_id, quantity) VALUES
(1, 1, 1, 2.00),
(2, 2, 4, 2.00),
(3, 3, 1, 2.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO payments (id, order_id, payment_method, payment_type, transaction_id, amount, status, paid_at) VALUES
(1, 1, 'payos', 'order_payment', 'PAYOS-20261124-001', 118500, 'paid', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(2, 2, 'payos', 'order_payment', 'PAYOS-20261124-002', 125000, 'paid', CURRENT_TIMESTAMP - INTERVAL '2 days'),
(3, 3, 'cod', 'order_payment', 'COD-20261124-003', 106000, 'paid', CURRENT_TIMESTAMP - INTERVAL '4 days'),
(4, 4, 'payos', 'order_payment', 'PAYOS-20261125-004', 156500, 'pending', NULL)
ON CONFLICT (id) DO NOTHING;

-- 9. GÓI RAU ĐỊNH KỲ (SUBSCRIPTION)
INSERT INTO subscriptions (id, customer_id, package_name, status, start_date, end_date, shipping_address, total_amount) VALUES
(1, (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), 'Gói Rau Gia Đình 4 Người (T3 & T6 hàng tuần)', 'active', CURRENT_DATE - INTERVAL '7 days', CURRENT_DATE + INTERVAL '23 days', '123 Nguyễn Huệ, Quận 1, TP.HCM', 860000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO subscription_items (id, subscription_id, product_id, quantity, unit_price) VALUES
(1, 1, 1, 2.00, 32300),
(2, 1, 2, 1.00, 38250)
ON CONFLICT (id) DO NOTHING;

INSERT INTO delivery_schedules (id, subscription_id, delivery_date, status, order_id) VALUES
(1, 1, CURRENT_DATE - INTERVAL '3 days', 'generated', 1),
(2, 1, CURRENT_DATE + INTERVAL '3 days', 'pending', NULL),
(3, 1, CURRENT_DATE + INTERVAL '7 days', 'pending', NULL)
ON CONFLICT (id) DO NOTHING;

-- 10. ĐÁNH GIÁ XÁC THỰC TỪ BẾP GIA ĐÌNH (REVIEWS)
INSERT INTO reviews (id, user_id, product_id, order_item_id, rating, comment, created_at) VALUES
(1, (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), 1, 1, 5, 'Cải thìa xào tỏi ngọt lịm không cần nêm bột ngọt luôn. Rau nhận lúc 11h sáng mở bẹ vẫn lạnh mát và giòn rụm, khác xa rau mua siêu thị bị nhạt.', CURRENT_TIMESTAMP - INTERVAL '1 day'),
(2, (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), 2, 2, 5, 'Thích nhất là quét mã QR thấy được video vườn cắt từ 5h sáng thiệt. Cà chua bi mọng nước, ăn sống rất ngọt.', CURRENT_TIMESTAMP - INTERVAL '3 days'),
(3, (SELECT id FROM profiles WHERE email = 'minhanh@gmail.com'), 1, 3, 5, 'Đóng gói túi giấy thoáng giữ lạnh tốt. Giá 38k cho 500g rau chất lượng canh tác thế này là quá hợp lý.', CURRENT_TIMESTAMP - INTERVAL '5 days')
ON CONFLICT (id) DO NOTHING;

-- 11. KHIẾU NẠI & BẰNG CHỨNG ẢNH (COMPLAINTS)
INSERT INTO complaints (id, order_item_id, quantity_affected, reason, description, requested_resolution, status, refund_amount, sales_note, handled_by) VALUES
(1, 2, 0.50, 'damaged', 'Có khoảng 500g cà chua bị dập nhẹ ở đáy hộp do va chạm lúc giao.', 'refund', 'pending', 0, NULL, NULL),
(2, 3, 0.50, 'expired_or_spoiled', '1 túi cải thìa có vài lá ngoài hơi héo, đã gửi ảnh trong vòng 24h.', 'refund', 'approved', 19000, 'Đã xác minh ảnh chụp, hoàn tiền 19.000đ qua ví khách hàng.', (SELECT id FROM profiles WHERE email = 'ngoc.sales@farmly.vn'))
ON CONFLICT (id) DO NOTHING;

INSERT INTO complaint_media (id, complaint_id, media_type, url, size_kb) VALUES
(1, 1, 'image', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=600', 420),
(2, 2, 'image', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600', 380)
ON CONFLICT (id) DO NOTHING;

-- 12. THÔNG BÁO HỆ THỐNG
INSERT INTO notifications (id, user_id, type, title, body, level) VALUES
(1, (SELECT id FROM profiles WHERE email = 'thuan.tran@farmly.vn'), 'batch_expired', 'Lô CUC02 (Dưa leo baby) đã quá hạn', 'Lô CUC02 còn tồn 14.2 kg đã hết hạn sử dụng. Vui lòng tạo phiếu xuất hủy kiểm định.', 'danger'),
(2, (SELECT id FROM profiles WHERE email = 'ngoc.sales@farmly.vn'), 'batch_expiring', 'Lô TOM04 sắp hết hạn trong 24 giờ', 'Cà chua bi TOM04 còn 32 kg. Đề xuất đẩy Flash Sale giảm 20% để xả kho theo FEFO.', 'warning')
ON CONFLICT (id) DO NOTHING;

-- 13. ĐỒNG BỘ LẠI TẤT CẢ SEQUENCES SAU KHI SEED
SELECT setval('addresses_id_seq', COALESCE((SELECT MAX(id) FROM addresses), 1));
SELECT setval('categories_id_seq', COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval('products_id_seq', COALESCE((SELECT MAX(id) FROM products), 1));
SELECT setval('product_images_id_seq', COALESCE((SELECT MAX(id) FROM product_images), 1));
SELECT setval('quality_certifications_id_seq', COALESCE((SELECT MAX(id) FROM quality_certifications), 1));
SELECT setval('batches_id_seq', COALESCE((SELECT MAX(id) FROM batches), 1));
SELECT setval('farming_logs_id_seq', COALESCE((SELECT MAX(id) FROM farming_logs), 1));
SELECT setval('inventory_disposals_id_seq', COALESCE((SELECT MAX(id) FROM inventory_disposals), 1));
SELECT setval('orders_id_seq', COALESCE((SELECT MAX(id) FROM orders), 1));
SELECT setval('order_items_id_seq', COALESCE((SELECT MAX(id) FROM order_items), 1));
SELECT setval('order_details_id_seq', COALESCE((SELECT MAX(id) FROM order_details), 1));
SELECT setval('payments_id_seq', COALESCE((SELECT MAX(id) FROM payments), 1));
SELECT setval('subscriptions_id_seq', COALESCE((SELECT MAX(id) FROM subscriptions), 1));
SELECT setval('subscription_items_id_seq', COALESCE((SELECT MAX(id) FROM subscription_items), 1));
SELECT setval('delivery_schedules_id_seq', COALESCE((SELECT MAX(id) FROM delivery_schedules), 1));
SELECT setval('reviews_id_seq', COALESCE((SELECT MAX(id) FROM reviews), 1));
SELECT setval('complaints_id_seq', COALESCE((SELECT MAX(id) FROM complaints), 1));
SELECT setval('complaint_media_id_seq', COALESCE((SELECT MAX(id) FROM complaint_media), 1));
SELECT setval('notifications_id_seq', COALESCE((SELECT MAX(id) FROM notifications), 1));
SELECT setval('activity_logs_id_seq', COALESCE((SELECT MAX(id) FROM activity_logs), 1));
