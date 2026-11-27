-- Farmly – Tạo 16 kiểu ENUM và 24 bảng (3NF)
-- Supabase migration, chạy theo thứ tự tên file (timestamp).

-- 1. TẠO CÁC KIỂU LIỆT KÊ (ENUMS)
CREATE TYPE user_role_enum AS ENUM ('customer', 'farm_staff', 'sales', 'admin');
CREATE TYPE batch_status_enum AS ENUM ('growing', 'in_stock', 'sold_out');
CREATE TYPE farming_stage_enum AS ENUM ('sowing', 'fertilizing', 'watering', 'pest_control', 'harvesting', 'packaging');
CREATE TYPE disposal_reason_enum AS ENUM ('damaged', 'rotten', 'expired', 'quality_failed', 'other');
CREATE TYPE order_type_enum AS ENUM ('retail', 'subscription', 'replacement');
CREATE TYPE order_status_enum AS ENUM ('pending', 'confirmed', 'preparing', 'shipping', 'delivered', 'cancelled');
CREATE TYPE payment_method_enum AS ENUM ('payos', 'cod');
CREATE TYPE payment_type_enum AS ENUM ('order_payment', 'subscription_payment', 'refund');
CREATE TYPE payment_status_enum AS ENUM ('pending', 'paid', 'failed', 'refunded');
CREATE TYPE subscription_status_enum AS ENUM ('pending_payment', 'active', 'paused', 'completed', 'cancelled');
CREATE TYPE schedule_status_enum AS ENUM ('pending', 'generated', 'skipped', 'cancelled');
CREATE TYPE complaint_reason_enum AS ENUM ('damaged', 'wrong_item', 'missing_quantity', 'expired_or_spoiled', 'late_delivery', 'other');
CREATE TYPE resolution_enum AS ENUM ('refund', 'replacement');
CREATE TYPE complaint_status_enum AS ENUM ('pending', 'approved', 'rejected', 'resolved');
CREATE TYPE media_type_enum AS ENUM ('image', 'video');
CREATE TYPE notification_level_enum AS ENUM ('info', 'warning', 'danger');

-- 2. TẠO 24 BẢNG DỮ LIỆU

-- Nhóm 1: Người dùng
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    avatar_url TEXT,
    role user_role_enum NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE addresses (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    recipient_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    address_line VARCHAR(255) NOT NULL,
    ward VARCHAR(100) NOT NULL,
    province VARCHAR(100) NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE carts (
    id SERIAL PRIMARY KEY,
    user_id UUID UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    guest_token VARCHAR(64) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_cart_owner CHECK (
        (user_id IS NOT NULL AND guest_token IS NULL) OR
        (user_id IS NULL AND guest_token IS NOT NULL)
    )
);

-- Nhóm 2: Sản phẩm & Lô hàng
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    slug VARCHAR(120) NOT NULL,
    description TEXT,
    image_url TEXT,
    allow_subscription BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(220) NOT NULL,
    unit VARCHAR(50) NOT NULL DEFAULT 'kg',
    base_price DECIMAL(12,2) NOT NULL CHECK (base_price >= 0),
    short_description TEXT,
    description TEXT,
    preservation_days INT NOT NULL DEFAULT 5 CHECK (preservation_days > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE cart_items (
    id SERIAL PRIMARY KEY,
    cart_id INT NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (cart_id, product_id)
);

CREATE TABLE product_images (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE quality_certifications (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    cert_name VARCHAR(150) NOT NULL,
    cert_number VARCHAR(100),
    issued_by VARCHAR(200),
    issue_date DATE,
    expiry_date DATE,
    file_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE batches (
    id SERIAL PRIMARY KEY,
    batch_code VARCHAR(100) UNIQUE NOT NULL,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    sowing_date DATE,
    harvest_date DATE,
    exp_date DATE,
    initial_quantity DECIMAL(10,2) NOT NULL CHECK (initial_quantity > 0),
    current_quantity DECIMAL(10,2) NOT NULL CHECK (current_quantity >= 0),
    disposed_quantity DECIMAL(10,2) NOT NULL DEFAULT 0 CHECK (disposed_quantity >= 0),
    qr_code TEXT UNIQUE,
    qr_scan_count INT NOT NULL DEFAULT 0 CHECK (qr_scan_count >= 0),
    status batch_status_enum NOT NULL DEFAULT 'growing',
    flash_sale_price DECIMAL(12,2) CHECK (flash_sale_price IS NULL OR flash_sale_price >= 0),
    flash_sale_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_batch_quantities CHECK (current_quantity + disposed_quantity <= initial_quantity),
    CONSTRAINT chk_batch_dates CHECK (
        (sowing_date IS NULL OR harvest_date IS NULL OR sowing_date <= harvest_date) AND
        (harvest_date IS NULL OR exp_date IS NULL OR harvest_date <= exp_date)
    ),
    CONSTRAINT chk_batch_harvest_state CHECK (
        (status = 'growing' AND harvest_date IS NULL AND qr_code IS NULL) OR
        (status IN ('in_stock', 'sold_out') AND harvest_date IS NOT NULL AND exp_date IS NOT NULL)
    )
);

CREATE TABLE farming_logs (
    id SERIAL PRIMARY KEY,
    batch_id INT NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    performed_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    stage farming_stage_enum NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    evidence_image_url TEXT,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory_disposals (
    id SERIAL PRIMARY KEY,
    batch_id INT NOT NULL REFERENCES batches(id) ON DELETE RESTRICT,
    quantity_disposed DECIMAL(10,2) NOT NULL CHECK (quantity_disposed > 0),
    reason disposal_reason_enum NOT NULL,
    note TEXT,
    image_url TEXT NOT NULL,
    disposed_by UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Nhóm 4: Gói định kỳ (Tạo trước Orders để Orders tham chiếu)
CREATE TABLE subscriptions (
    id SERIAL PRIMARY KEY,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    package_name VARCHAR(150) NOT NULL,
    status subscription_status_enum NOT NULL DEFAULT 'pending_payment',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL CHECK (end_date >= start_date),
    shipping_address TEXT NOT NULL,
    total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE subscription_items (
    id SERIAL PRIMARY KEY,
    subscription_id INT NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    UNIQUE (subscription_id, product_id)
);

-- Nhóm 3: Đơn hàng & Thanh toán
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(100) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE RESTRICT,
    subscription_id INT REFERENCES subscriptions(id) ON DELETE SET NULL,
    confirmed_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    order_type order_type_enum NOT NULL DEFAULT 'retail',
    status order_status_enum NOT NULL DEFAULT 'pending',
    customer_name VARCHAR(150) NOT NULL,
    customer_phone VARCHAR(20) NOT NULL,
    shipping_address TEXT NOT NULL,
    distance_km DECIMAL(6,2) NOT NULL DEFAULT 0 CHECK (distance_km >= 0),
    shipping_fee DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (shipping_fee >= 0),
    total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
    customer_note TEXT,
    expected_delivery_date DATE,
    delivered_at TIMESTAMPTZ,
    cancel_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE delivery_schedules (
    id SERIAL PRIMARY KEY,
    subscription_id INT NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    delivery_date DATE NOT NULL,
    status schedule_status_enum NOT NULL DEFAULT 'pending',
    order_id INT UNIQUE REFERENCES orders(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (subscription_id, delivery_date)
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name VARCHAR(200) NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL CHECK (unit_price >= 0),
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0)
);

CREATE TABLE order_details (
    id SERIAL PRIMARY KEY,
    order_item_id INT NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    batch_id INT NOT NULL REFERENCES batches(id) ON DELETE RESTRICT,
    quantity DECIMAL(10,2) NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id) ON DELETE RESTRICT,
    subscription_id INT REFERENCES subscriptions(id) ON DELETE RESTRICT,
    payment_method payment_method_enum NOT NULL,
    payment_type payment_type_enum NOT NULL DEFAULT 'order_payment',
    transaction_id VARCHAR(100) UNIQUE,
    payos_order_code BIGINT UNIQUE,
    amount DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    status payment_status_enum NOT NULL DEFAULT 'pending',
    qr_code_url TEXT,
    gateway_response JSONB,
    expires_at TIMESTAMPTZ,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_payment_target CHECK (
        (order_id IS NOT NULL AND subscription_id IS NULL) OR
        (order_id IS NULL AND subscription_id IS NOT NULL)
    )
);

-- Nhóm 5: Khiếu nại & Đánh giá
CREATE TABLE complaints (
    id SERIAL PRIMARY KEY,
    order_item_id INT NOT NULL REFERENCES order_items(id) ON DELETE RESTRICT,
    quantity_affected DECIMAL(10,2) NOT NULL CHECK (quantity_affected > 0),
    reason complaint_reason_enum NOT NULL,
    description TEXT,
    requested_resolution resolution_enum NOT NULL,
    status complaint_status_enum NOT NULL DEFAULT 'pending',
    refund_amount DECIMAL(12,2) CHECK (refund_amount IS NULL OR refund_amount >= 0),
    replacement_order_id INT REFERENCES orders(id) ON DELETE SET NULL,
    sales_note TEXT,
    handled_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_complaint_reject_note CHECK (
        status <> 'rejected' OR (sales_note IS NOT NULL AND LENGTH(TRIM(sales_note)) > 0)
    )
);

CREATE TABLE complaint_media (
    id SERIAL PRIMARY KEY,
    complaint_id INT NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
    media_type media_type_enum NOT NULL,
    url TEXT NOT NULL,
    size_kb INT NOT NULL CHECK (
        (media_type = 'image' AND size_kb > 0 AND size_kb <= 5120) OR
        (media_type = 'video' AND size_kb > 0 AND size_kb <= 51200)
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    order_item_id INT UNIQUE NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Nhóm 6: Hệ thống
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(150) NOT NULL,
    body TEXT NOT NULL,
    level notification_level_enum NOT NULL DEFAULT 'info',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE settings (
    key VARCHAR(100) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE activity_logs (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
