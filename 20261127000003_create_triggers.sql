-- Farmly – Trigger: updated_at, kiểm tra lô đúng sản phẩm, xuất huỷ, tạo profile, xoá mềm
-- Supabase migration, chạy theo thứ tự tên file (timestamp).

-- 4. TRIGGERS NGHIỆP VỤ & TOÀN VẸN DỮ LIỆU

-- 4.1 Tự động cập nhật updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_addresses_updated BEFORE UPDATE ON addresses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_categories_updated BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_products_updated BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_batches_updated BEFORE UPDATE ON batches FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_subscriptions_updated BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_complaints_updated BEFORE UPDATE ON complaints FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 4.2 Vá lỗi Tuần 3: Kiểm tra batch_id trong order_details phải thuộc đúng product_id của order_item
CREATE OR REPLACE FUNCTION check_order_detail_batch_product()
RETURNS TRIGGER AS $$
DECLARE
    v_item_product_id INT;
    v_batch_product_id INT;
BEGIN
    SELECT product_id INTO v_item_product_id FROM order_items WHERE id = NEW.order_item_id;
    SELECT product_id INTO v_batch_product_id FROM batches WHERE id = NEW.batch_id;

    IF v_item_product_id IS NULL OR v_batch_product_id IS NULL OR v_item_product_id <> v_batch_product_id THEN
        RAISE EXCEPTION 'Toàn vẹn dữ liệu: Lô hàng (%) không thuộc sản phẩm của dòng đơn hàng (%)', NEW.batch_id, NEW.order_item_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_order_detail_batch_product
BEFORE INSERT OR UPDATE ON order_details
FOR EACH ROW EXECUTE FUNCTION check_order_detail_batch_product();

-- 4.3 Tự động trừ kho & cộng dồn hao hụt khi Farm Staff tạo phiếu xuất hủy
CREATE OR REPLACE FUNCTION handle_inventory_disposal()
RETURNS TRIGGER AS $$
DECLARE
    v_current DECIMAL(10,2);
BEGIN
    SELECT current_quantity INTO v_current FROM batches WHERE id = NEW.batch_id FOR UPDATE;
    IF v_current < NEW.quantity_disposed THEN
        RAISE EXCEPTION 'Số lượng xuất hủy (%) vượt quá tồn kho hiện tại (%) của lô %', NEW.quantity_disposed, v_current, NEW.batch_id;
    END IF;

    UPDATE batches
    SET current_quantity = current_quantity - NEW.quantity_disposed,
        disposed_quantity = disposed_quantity + NEW.quantity_disposed,
        status = CASE WHEN (current_quantity - NEW.quantity_disposed) = 0 THEN 'sold_out' ELSE status END
    WHERE id = NEW.batch_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_inventory_disposal
AFTER INSERT ON inventory_disposals
FOR EACH ROW EXECUTE FUNCTION handle_inventory_disposal();

-- 4.4 Tự động tạo profile khi user đăng ký qua Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'full_name', ''), split_part(NEW.email, '@', 1)),
        COALESCE(NULLIF(NEW.raw_user_meta_data->>'role', '')::public.user_role_enum, 'customer'::public.user_role_enum)
    );
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION handle_new_auth_user();

-- 4.5 Xóa mềm (Soft Delete) cho 4 bảng danh mục
CREATE OR REPLACE FUNCTION soft_delete_record()
RETURNS TRIGGER AS $$
BEGIN
    EXECUTE format('UPDATE %I.%I SET deleted_at = NOW() WHERE id = $1', TG_TABLE_SCHEMA, TG_TABLE_NAME)
    USING OLD.id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_soft_delete_categories BEFORE DELETE ON categories FOR EACH ROW EXECUTE FUNCTION soft_delete_record();
CREATE TRIGGER trg_soft_delete_products BEFORE DELETE ON products FOR EACH ROW EXECUTE FUNCTION soft_delete_record();
CREATE TRIGGER trg_soft_delete_product_images BEFORE DELETE ON product_images FOR EACH ROW EXECUTE FUNCTION soft_delete_record();
CREATE TRIGGER trg_soft_delete_certifications BEFORE DELETE ON quality_certifications FOR EACH ROW EXECUTE FUNCTION soft_delete_record();
