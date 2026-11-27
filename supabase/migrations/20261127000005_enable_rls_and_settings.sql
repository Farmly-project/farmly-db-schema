-- Farmly – Bật Row Level Security, chính sách phân quyền và cấu hình mặc định
-- Supabase migration, chạy theo thứ tự tên file (timestamp).

-- 6. BẬT ROW LEVEL SECURITY (RLS) & CHÍNH SÁCH PHÂN QUYỀN CƠ BẢN
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE carts ENABLE ROW LEVEL SECURITY;
ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE quality_certifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE farming_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_disposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;

-- Hàm helper lấy role của user hiện tại
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS user_role_enum AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Public Read (Khách vãng lai & người quét QR được xem)
CREATE POLICY "Public read categories" ON categories FOR SELECT USING (deleted_at IS NULL AND is_active = TRUE);
CREATE POLICY "Public read products" ON products FOR SELECT USING (deleted_at IS NULL AND is_active = TRUE);
CREATE POLICY "Public read product_images" ON product_images FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Public read certifications" ON quality_certifications FOR SELECT USING (deleted_at IS NULL);
CREATE POLICY "Public read batches for QR" ON batches FOR SELECT USING (TRUE);
CREATE POLICY "Public read farming_logs for QR" ON farming_logs FOR SELECT USING (TRUE);
CREATE POLICY "Public read reviews" ON reviews FOR SELECT USING (deleted_at IS NULL);

-- Customer Policies (Chỉ thao tác dữ liệu của chính mình)
CREATE POLICY "Users manage own profile" ON profiles FOR ALL USING (id = auth.uid() OR current_user_role() = 'admin');
CREATE POLICY "Users manage own addresses" ON addresses FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users manage own orders" ON orders FOR SELECT USING (customer_id = auth.uid() OR current_user_role() IN ('sales', 'admin'));
CREATE POLICY "Users manage own notifications" ON notifications FOR ALL USING (user_id = auth.uid());

-- Farm Staff & Admin Policies
CREATE POLICY "Farm staff manage batches" ON batches FOR ALL USING (current_user_role() IN ('farm_staff', 'admin'));
CREATE POLICY "Farm staff manage logs" ON farming_logs FOR ALL USING (current_user_role() IN ('farm_staff', 'admin'));
CREATE POLICY "Farm staff manage disposals" ON inventory_disposals FOR ALL USING (current_user_role() IN ('farm_staff', 'admin'));

-- Admin Policies
CREATE POLICY "Admin full access categories" ON categories FOR ALL USING (current_user_role() = 'admin');
CREATE POLICY "Admin full access products" ON products FOR ALL USING (current_user_role() = 'admin');
CREATE POLICY "Admin full access settings" ON settings FOR ALL USING (current_user_role() = 'admin');

-- 7. DỮ LIỆU CẤU HÌNH MẶC ĐỊNH
INSERT INTO settings (key, value) VALUES
('expiry_warning_days', '2'),
('shipping_fee_per_km', '5000'),
('farm_latitude', '10.7769'),
('farm_longitude', '106.7009');
