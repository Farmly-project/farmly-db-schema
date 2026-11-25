-- =============================================================================
-- DỮ LIỆU MẪU KIỂM THỬ FEFO VÀ HỆ THỐNG FARMLY (SEED DATA)
-- =============================================================================

-- 1. Tài khoản người dùng mẫu
INSERT INTO profiles (id, email, full_name, phone, role) VALUES
('00000000-0000-0000-0000-000000000001', 'admin@farmly.vn', 'Quản trị viên Farmly', '0901234567', 'admin'),
('00000000-0000-0000-0000-000000000002', 'staff@farmly.vn', 'Kỹ sư Canh tác Farm', '0902345678', 'farm_staff'),
('00000000-0000-0000-0000-000000000003', 'sales@farmly.vn', 'Nhân viên CSKH / Sales', '0903456789', 'sales'),
('00000000-0000-0000-0000-000000000004', 'customer@gmail.com', 'Nguyễn Thị Khách Hàng', '0909876543', 'customer')
ON CONFLICT (email) DO NOTHING;

-- Địa chỉ giao hàng mặc định của khách
INSERT INTO addresses (user_id, recipient_name, phone, address_line, ward, province, is_default) VALUES
('00000000-0000-0000-0000-000000000004', 'Nguyễn Thị Khách Hàng', '0909876543', '123 Đường Nguyễn Huệ, Bến Nghé', 'Quận 1', 'TP. Hồ Chí Minh', true)
ON CONFLICT DO NOTHING;

-- 2. Cài đặt hệ thống
INSERT INTO settings (key, value) VALUES
('warning_days_before_expiry', '2'),
('farm_lat', '10.9805'),
('farm_lng', '106.5050'),
('shipping_fee_per_km', '5000'),
('min_shipping_fee', '15000')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 3. Danh mục sản phẩm
INSERT INTO categories (id, name, slug, description, image_url, allow_subscription, is_active) VALUES
(1, 'Rau ăn lá hữu cơ', 'rau-an-la-huu-co', 'Các loại rau xanh tươi non thu hoạch mỗi sáng sớm', 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=500', true, true),
(2, 'Củ quả tươi sạch', 'cu-qua-tuoi-sach', 'Cà chua, dưa chuột, ớt chuông trồng theo tiêu chuẩn VietGAP', 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=500', true, true),
(3, 'Nấm & Thảo mộc', 'nam-thao-moc', 'Nấm sạch và rau gia vị thơm ngon cho bữa ăn gia đình', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500', false, true)
ON CONFLICT (id) DO NOTHING;

-- 4. Sản phẩm
INSERT INTO products (id, category_id, name, slug, unit, base_price, short_description, description, preservation_days, is_active) VALUES
(1, 1, 'Cải thìa hữu cơ', 'cai-thia-huu-co', 'kg', 35000, 'Cải thìa chuẩn hữu cơ, bẹ dày, giòn ngọt tự nhiên.', 'Trồng trong nhà kính tại Nông trại Củ Chi theo quy trình vi sinh không hóa chất. Thu hoạch khi vừa đạt độ giòn ngọt nhất.', 5, true),
(2, 2, 'Cà chua bi baby', 'ca-chua-bi-baby', 'kg', 45000, 'Cà chua bi mọng nước, vị ngọt thanh giàu vitamin C.', 'Cà chua bi giống Hà Lan được thụ phấn tự nhiên bởi ong, không sử dụng chất kích thích tăng trưởng.', 10, true),
(3, 1, 'Xà lách Lolo xanh', 'xa-lach-lolo-xanh', 'kg', 40000, 'Xà lách thủy canh giòn ngọt, thích hợp làm salad tươi.', 'Canh tác thủy canh tuần hoàn khép kín, không dư lượng kim loại nặng hay thuốc bảo vệ thực vật.', 4, true)
ON CONFLICT (id) DO NOTHING;

-- Ảnh sản phẩm
INSERT INTO product_images (product_id, image_url, is_primary, display_order) VALUES
(1, 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800', true, 1),
(2, 'https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=800', true, 1),
(3, 'https://images.unsplash.com/photo-1556801712-76c8eb07bbc9?w=800', true, 1)
ON CONFLICT DO NOTHING;

-- Chứng nhận chất lượng
INSERT INTO quality_certifications (product_id, cert_name, cert_number, issued_by, issue_date, expiry_date, file_url) VALUES
(1, 'VietGAP Trồng Trọt', 'VG-2026-CC01', 'Trung tâm Giám định Nông nghiệp TP.HCM', '2026-01-10', '2027-01-10', 'https://farmly.vn/certs/vietgap-01.pdf'),
(2, 'GlobalGAP Organic', 'GG-VN-2026-99', 'Control Union Certifications', '2026-02-15', '2027-02-15', 'https://farmly.vn/certs/globalgap-02.pdf')
ON CONFLICT DO NOTHING;

-- 5. LÔ HÀNG THỬ NGHIỆM THUẬT TOÁN FEFO
-- Kịch bản: Cải thìa (product_id = 1) có 4 lô để test các case:
-- Lô 1: CẬN HẠN (Còn 2 ngày) -> FEFO phải chọn trừ lô này TRƯỚC TIÊN
-- Lô 2: BÌNH THƯỜNG (Còn 7 ngày) -> FEFO lấy tiếp khi Lô 1 không đủ
-- Lô 3: ĐÃ QUÁ HẠN (Hết hạn từ hôm qua) -> FEFO bắt buộc BỎ QUA
-- Lô 4: ĐÃ HẾT HÀNG (Tồn 0) -> FEFO bắt buộc BỎ QUA
INSERT INTO batches (id, batch_code, product_id, sowing_date, harvest_date, exp_date, initial_quantity, current_quantity, disposed_quantity, qr_code, status) VALUES
(1, 'BATCH-CAITHIA-20261125-01', 1, CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '3 days', CURRENT_DATE + INTERVAL '2 days', 20.00, 3.00, 2.00, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-20261125-01', 'in_stock'),
(2, 'BATCH-CAITHIA-20261125-02', 1, CURRENT_DATE - INTERVAL '25 days', CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', 30.00, 25.00, 0.00, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-20261125-02', 'in_stock'),
(3, 'BATCH-CAITHIA-20261120-EXPIRED', 1, CURRENT_DATE - INTERVAL '40 days', CURRENT_DATE - INTERVAL '10 days', CURRENT_DATE - INTERVAL '1 day', 15.00, 5.00, 0.00, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-EXPIRED', 'in_stock'),
(4, 'BATCH-CAITHIA-20261115-SOLDOUT', 1, CURRENT_DATE - INTERVAL '45 days', CURRENT_DATE - INTERVAL '15 days', CURRENT_DATE + INTERVAL '5 days', 20.00, 0.00, 0.00, 'https://farmly.vn/truy-xuat/BATCH-CAITHIA-SOLDOUT', 'sold_out'),
-- Lô Cà chua bi
(5, 'BATCH-CACHUA-20261125-01', 2, CURRENT_DATE - INTERVAL '60 days', CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '5 days', 50.00, 15.00, 1.00, 'https://farmly.vn/truy-xuat/BATCH-CACHUA-20261125-01', 'in_stock'),
(6, 'BATCH-CACHUA-20261125-02', 2, CURRENT_DATE - INTERVAL '50 days', CURRENT_DATE, CURRENT_DATE + INTERVAL '12 days', 50.00, 50.00, 0.00, 'https://farmly.vn/truy-xuat/BATCH-CACHUA-20261125-02', 'in_stock')
ON CONFLICT (id) DO UPDATE SET 
    current_quantity = EXCLUDED.current_quantity,
    exp_date = EXCLUDED.exp_date,
    status = EXCLUDED.status;

-- 6. Nhật ký canh tác cho Lô 1 (để hiển thị Timeline trên trang Chi tiết sản phẩm)
INSERT INTO farming_logs (batch_id, performed_by, stage, title, description, evidence_image_url, logged_at) VALUES
(1, '00000000-0000-0000-0000-000000000002', 'soil_prep', 'Làm đất & Xử lý giá thể vi sinh', 'Đất vườn ủ men vi sinh trichoderma khử khuẩn 7 ngày trước gieo hạt.', 'https://images.unsplash.com/photo-1585320806297-9794b3e4eeae?w=600', CURRENT_TIMESTAMP - INTERVAL '33 days'),
(1, '00000000-0000-0000-0000-000000000002', 'sowing', 'Gieo hạt giống hữu cơ F1', 'Gieo hạt giống cải thìa trên khay xốp hữu cơ, nhiệt độ 26°C.', 'https://images.unsplash.com/photo-1592417817098-8f3d6910985c?w=600', CURRENT_TIMESTAMP - INTERVAL '30 days'),
(1, '00000000-0000-0000-0000-000000000002', 'fertilizing', 'Bón thúc đợt 1 bằng phân trùn quế', 'Bổ sung dịch trùn quế pha loãng tỷ lệ 1:200, tưới rễ buổi sáng sớm.', 'https://images.unsplash.com/photo-1591857177580-dc82b9ac4e1e?w=600', CURRENT_TIMESTAMP - INTERVAL '20 days'),
(1, '00000000-0000-0000-0000-000000000002', 'pest_control', 'Xử lý sâu bệnh bằng tinh dầu tỏi ớt', 'Phun chế phẩm thảo mộc xua đuổi bọ nhảy, không dùng hóa chất.', 'https://images.unsplash.com/photo-1628352081506-83c43123ed6d?w=600', CURRENT_TIMESTAMP - INTERVAL '10 days'),
(1, '00000000-0000-0000-0000-000000000002', 'harvesting', 'Thu hoạch sáng sớm & đóng gói', 'Thu hoạch vào lúc 05:30 sáng, cắt gốc rửa nước ozone và dán tem QR.', 'https://images.unsplash.com/photo-1595855759920-86582396756a?w=600', CURRENT_TIMESTAMP - INTERVAL '3 days')
ON CONFLICT DO NOTHING;

-- Cập nhật chuỗi sequence của ID nếu cần
SELECT setval('products_id_seq', (SELECT MAX(id) FROM products));
SELECT setval('categories_id_seq', (SELECT MAX(id) FROM categories));
SELECT setval('batches_id_seq', (SELECT MAX(id) FROM batches));
