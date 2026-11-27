-- =============================================================================
-- DỮ LIỆU MẪU KIỂM THỬ FEFO VÀ HỆ THỐNG FARMLY (SEED DATA) – bản đã sửa
-- Chạy SAU script tạo bảng (scrip_sql). Có thể chạy lại nhiều lần.
-- =============================================================================

-- 1. TÀI KHOẢN MẪU
-- profiles.id tham chiếu auth.users(id), nên phải tạo user trong auth.users trước.
-- Trigger on_auth_user_created sẽ tự tạo profiles với role lấy từ raw_user_meta_data.
-- Mật khẩu chung để test: Farmly@123
-- (Nếu nhóm đã tạo 4 tài khoản này bằng Supabase Dashboard thì bỏ qua khối DO bên dưới.)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    u RECORD;
BEGIN
    FOR u IN
        SELECT * FROM (VALUES
            ('00000000-0000-0000-0000-000000000001'::uuid, 'admin@farmly.vn',    'Quản trị viên Farmly',   'admin'),
            ('00000000-0000-0000-0000-000000000002'::uuid, 'staff@farmly.vn',    'Kỹ sư Canh tác Farm',    'farm_staff'),
            ('00000000-0000-0000-0000-000000000003'::uuid, 'sales@farmly.vn',    'Nhân viên CSKH / Sales', 'sales'),
            ('00000000-0000-0000-0000-000000000004'::uuid, 'customer@gmail.com', 'Nguyễn Thị Khách Hàng',  'customer')
        ) AS t(id, email, full_name, role)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = u.id OR email = u.email) THEN
            INSERT INTO auth.users (
                id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
                raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                confirmation_token, recovery_token, email_change_token_new, email_change
            ) VALUES (
                u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
                u.email, crypt('Farmly@123', gen_salt('bf')), NOW(),
                '{"provider":"email","providers":["email"]}',
                jsonb_build_object('full_name', u.full_name, 'role', u.role),
                NOW(), NOW(), '', '', '', ''
            );
            INSERT INTO auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
            VALUES (gen_random_uuid(), u.id, u.id::text,
                    jsonb_build_object('sub', u.id::text, 'email', u.email), 'email', NOW(), NOW(), NOW());
        END IF;
    END LOOP;
END $$;

-- Bổ sung số điện thoại và đảm bảo đúng role (phòng trường hợp profile tạo trước với role mặc định)
UPDATE profiles p SET phone = v.phone, role = v.role::user_role_enum, full_name = v.full_name
FROM (VALUES
    ('00000000-0000-0000-0000-000000000001'::uuid, '0901234567', 'admin',      'Quản trị viên Farmly'),
    ('00000000-0000-0000-0000-000000000002'::uuid, '0902345678', 'farm_staff', 'Kỹ sư Canh tác Farm'),
    ('00000000-0000-0000-0000-000000000003'::uuid, '0903456789', 'sales',      'Nhân viên CSKH / Sales'),
    ('00000000-0000-0000-0000-000000000004'::uuid, '0909876543', 'customer',   'Nguyễn Thị Khách Hàng')
) AS v(id, phone, role, full_name)
WHERE p.id = v.id;

-- Địa chỉ giao hàng mặc định của khách
INSERT INTO addresses (user_id, recipient_name, phone, address_line, ward, province, is_default)
SELECT '00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ', 'Phường Bến Nghé', 'TP. Hồ Chí Minh', TRUE
WHERE NOT EXISTS (SELECT 1 FROM addresses WHERE user_id = '00000000-0000-0000-0000-000000000004');

-- 2. CÀI ĐẶT HỆ THỐNG (dùng đúng tên key trong script tạo bảng)
INSERT INTO settings (key, value) VALUES
('expiry_warning_days', '2'),
('farm_latitude', '10.9805'),
('farm_longitude', '106.5050'),
('shipping_fee_per_km', '5000'),
('min_shipping_fee', '15000')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- 3. DANH MỤC SẢN PHẨM
INSERT INTO categories (id, name, slug, description, image_url, allow_subscription, is_active) VALUES
(1, 'Rau ăn lá hữu cơ', 'rau-an-la-huu-co', 'Các loại rau xanh tươi non thu hoạch mỗi sáng sớm', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500', TRUE, TRUE),
(2, 'Củ quả tươi sạch', 'cu-qua-tuoi-sach', 'Cà chua, dưa chuột, ớt chuông trồng theo tiêu chuẩn VietGAP', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500', TRUE, TRUE),
(3, 'Nấm & Thảo mộc', 'nam-thao-moc', 'Nấm sạch và rau gia vị thơm ngon cho bữa ăn gia đình', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500', FALSE, TRUE)
ON CONFLICT (id) DO NOTHING;

-- 4. SẢN PHẨM
INSERT INTO products (id, category_id, name, slug, unit, base_price, short_description, description, preservation_days, is_active) VALUES
(1, 1, 'Cải thìa hữu cơ', 'cai-thia-huu-co', 'kg', 35000, 'Cải thìa chuẩn hữu cơ, bẹ dày, giòn ngọt tự nhiên.', 'Trồng trong nhà kính tại Nông trại Củ Chi theo quy trình vi sinh không hóa chất. Thu hoạch khi vừa đạt độ giòn ngọt nhất.', 5, TRUE),
(2, 2, 'Cà chua bi baby', 'ca-chua-bi-baby', 'kg', 45000, 'Cà chua bi mọng nước, vị ngọt thanh giàu vitamin C.', 'Cà chua bi giống Hà Lan được thụ phấn tự nhiên bởi ong, không sử dụng chất kích thích tăng trưởng.', 10, TRUE),
(3, 1, 'Xà lách Lolo xanh', 'xa-lach-lolo-xanh', 'kg', 40000, 'Xà lách thủy canh giòn ngọt, thích hợp làm salad tươi.', 'Canh tác thủy canh tuần hoàn khép kín, không dư lượng kim loại nặng hay thuốc bảo vệ thực vật.', 4, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Ảnh sản phẩm (không có UNIQUE nên kiểm tra tồn tại để chạy lại không bị trùng)
INSERT INTO product_images (product_id, image_url, is_primary, display_order)
SELECT v.* FROM (VALUES
    (1, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800', TRUE, 1),
    (2, 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800', TRUE, 1),
    (3, 'https://images.unsplash.com/photo-1556801712-76c8eb07bbc9?w=800', TRUE, 1)
) AS v(product_id, image_url, is_primary, display_order)
WHERE NOT EXISTS (SELECT 1 FROM product_images pi WHERE pi.product_id = v.product_id AND pi.image_url = v.image_url);

-- Chứng nhận chất lượng
INSERT INTO quality_certifications (product_id, cert_name, cert_number, issued_by, issue_date, expiry_date, file_url)
SELECT v.* FROM (VALUES
    (1, 'VietGAP Trồng Trọt', 'VG-2026-CC01', 'Trung tâm Giám định Nông nghiệp TP.HCM', DATE '2026-01-10', DATE '2027-01-10', 'https://farmly.vn/certs/vietgap-01.pdf'),
    (2, 'GlobalGAP Organic', 'GG-VN-2026-99', 'Control Union Certifications', DATE '2026-02-15', DATE '2027-02-15', 'https://farmly.vn/certs/globalgap-02.pdf')
) AS v(product_id, cert_name, cert_number, issued_by, issue_date, expiry_date, file_url)
WHERE NOT EXISTS (SELECT 1 FROM quality_certifications q WHERE q.cert_number = v.cert_number);

-- 5. LÔ HÀNG THỬ NGHIỆM THUẬT TOÁN FEFO
-- Cải thìa (product 1):
--   Lô 1  CẬN HẠN còn 2 ngày, tồn 3 kg   -> FEFO lấy TRƯỚC
--   Lô 2  còn 7 ngày, tồn 25 kg           -> FEFO lấy tiếp
--   Lô 3  ĐÃ QUÁ HẠN (hôm qua), tồn 5 kg  -> FEFO phải BỎ QUA
--   Lô 4  HẾT HÀNG (tồn 0)                -> FEFO phải BỎ QUA
--   Lô 9  ĐANG TRỒNG (growing)            -> FEFO phải BỎ QUA
-- Cà chua bi (product 2) – đúng ví dụ của đề "mua 10 kg cà chua":
--   Lô 5  còn 5 ngày, tồn 3 kg  -> trừ 3 kg
--   Lô 6  còn 12 ngày, tồn 50 kg -> trừ tiếp 7 kg
-- Xà lách (product 3) – kịch bản THIẾU HÀNG của đề "tổng kho chỉ có 8 kg":
--   Lô 7  còn 3 ngày, tồn 5 kg
--   Lô 8  còn 4 ngày, tồn 3 kg   -> đặt 10 kg phải báo lỗi, rollback
INSERT INTO batches (id, batch_code, product_id, sowing_date, harvest_date, exp_date, initial_quantity, current_quantity, disposed_quantity, qr_code, status) VALUES
(1, 'BATCH-CAITHIA-01', 1, CURRENT_DATE - 30, CURRENT_DATE - 3,  CURRENT_DATE + 2,  20, 3,  2, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-01', 'in_stock'),
(2, 'BATCH-CAITHIA-02', 1, CURRENT_DATE - 25, CURRENT_DATE,      CURRENT_DATE + 7,  30, 25, 0, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-02', 'in_stock'),
(3, 'BATCH-CAITHIA-EXPIRED', 1, CURRENT_DATE - 40, CURRENT_DATE - 10, CURRENT_DATE - 1, 15, 5, 0, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-EXPIRED', 'in_stock'),
(4, 'BATCH-CAITHIA-SOLDOUT', 1, CURRENT_DATE - 45, CURRENT_DATE - 15, CURRENT_DATE + 5, 20, 0, 0, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-SOLDOUT', 'sold_out'),
(5, 'BATCH-CACHUA-01', 2, CURRENT_DATE - 60, CURRENT_DATE - 2,  CURRENT_DATE + 5,  50, 3,  1, 'https://farmly.vn/truy-xuat/BATCH-CACHUA-01', 'in_stock'),
(6, 'BATCH-CACHUA-02', 2, CURRENT_DATE - 50, CURRENT_DATE,      CURRENT_DATE + 12, 50, 50, 0, 'https://farmly.vn/truy-xuat/BATCH-CACHUA-02', 'in_stock'),
(7, 'BATCH-XALACH-01', 3, CURRENT_DATE - 35, CURRENT_DATE - 1,  CURRENT_DATE + 3,  10, 5,  0, 'https://farmly.vn/truy-xuat/BATCH-XALACH-01', 'in_stock'),
(8, 'BATCH-XALACH-02', 3, CURRENT_DATE - 33, CURRENT_DATE,      CURRENT_DATE + 4,  10, 3,  0, 'https://farmly.vn/truy-xuat/BATCH-XALACH-02', 'in_stock'),
(9, 'BATCH-CAITHIA-GROWING', 1, CURRENT_DATE - 10, NULL, NULL, 25, 25, 0, NULL, 'growing')
ON CONFLICT (id) DO UPDATE SET
    batch_code = EXCLUDED.batch_code,
    product_id = EXCLUDED.product_id,
    sowing_date = EXCLUDED.sowing_date,
    harvest_date = EXCLUDED.harvest_date,
    exp_date = EXCLUDED.exp_date,
    initial_quantity = EXCLUDED.initial_quantity,
    current_quantity = EXCLUDED.current_quantity,
    disposed_quantity = EXCLUDED.disposed_quantity,
    qr_code = EXCLUDED.qr_code,
    status = EXCLUDED.status;

-- 6. NHẬT KÝ CANH TÁC CHO LÔ 1 (Timeline trên trang Chi tiết sản phẩm)
-- stage phải thuộc farming_stage_enum: sowing, fertilizing, watering, pest_control, harvesting, packaging
INSERT INTO farming_logs (batch_id, performed_by, stage, title, description, evidence_image_url, logged_at)
SELECT v.* FROM (VALUES
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'sowing'::farming_stage_enum, 'Gieo hạt giống hữu cơ F1', 'Gieo hạt giống cải thìa trên khay xốp hữu cơ, giá thể đã ủ men vi sinh Trichoderma 7 ngày.', 'https://images.unsplash.com/photo-1592417817098-8f3d6910985c?w=600', NOW() - INTERVAL '30 days'),
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'watering'::farming_stage_enum, 'Tưới nhỏ giọt định kỳ', 'Tưới nhỏ giọt 2 lần/ngày, kiểm tra độ ẩm giá thể 70–80%.', 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600', NOW() - INTERVAL '25 days'),
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'fertilizing'::farming_stage_enum, 'Bón thúc đợt 1 bằng phân trùn quế', 'Bổ sung dịch trùn quế pha loãng tỷ lệ 1:200, tưới rễ buổi sáng sớm.', 'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?w=600', NOW() - INTERVAL '20 days'),
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'pest_control'::farming_stage_enum, 'Xử lý sâu bệnh bằng tinh dầu tỏi ớt', 'Phun chế phẩm thảo mộc xua đuổi bọ nhảy, không dùng hóa chất.', 'https://images.unsplash.com/photo-1628352081506-83c43123ed6d?w=600', NOW() - INTERVAL '10 days'),
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'harvesting'::farming_stage_enum, 'Thu hoạch sáng sớm', 'Thu hoạch lúc 05:30 sáng, cắt gốc và rửa bằng nước ozone.', 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=600', NOW() - INTERVAL '3 days'),
    (1, '00000000-0000-0000-0000-000000000002'::uuid, 'packaging'::farming_stage_enum, 'Đóng gói và dán tem QR', 'Đóng túi 500 g, dán tem QR truy xuất của lô BATCH-CAITHIA-01.', 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=600', NOW() - INTERVAL '3 days' + INTERVAL '2 hours')
) AS v(batch_id, performed_by, stage, title, description, evidence_image_url, logged_at)
WHERE NOT EXISTS (SELECT 1 FROM farming_logs f WHERE f.batch_id = v.batch_id AND f.title = v.title);

-- 7. CẬP NHẬT SEQUENCE SAU KHI CHÈN ID THỦ CÔNG
SELECT setval('products_id_seq',   (SELECT MAX(id) FROM products));
SELECT setval('categories_id_seq', (SELECT MAX(id) FROM categories));
SELECT setval('batches_id_seq',    (SELECT MAX(id) FROM batches));
