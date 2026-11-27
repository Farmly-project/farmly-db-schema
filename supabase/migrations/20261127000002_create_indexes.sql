-- Farmly – Chỉ mục phụ (FEFO, đơn hàng, khoá ngoại, xoá mềm)
-- Supabase migration, chạy theo thứ tự tên file (timestamp).

-- 3. CHIẾN LƯỢC INDEX (36 INDEXES TỐI ƯU FEFO & TRUY VẤN)
CREATE UNIQUE INDEX uq_categories_slug_alive ON categories(slug) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX uq_products_slug_alive ON products(slug) WHERE deleted_at IS NULL;

-- Index bắt buộc của đề & Tối ưu thuật toán FEFO
CREATE INDEX idx_batches_fefo ON batches(product_id, exp_date ASC, created_at ASC)
    WHERE status = 'in_stock' AND current_quantity > 0;
CREATE INDEX idx_batches_exp_date ON batches(exp_date) WHERE status = 'in_stock';
CREATE INDEX idx_batches_product ON batches(product_id);

CREATE INDEX idx_farming_logs_batch_time ON farming_logs(batch_id, logged_at ASC);
CREATE INDEX idx_farming_logs_staff ON farming_logs(performed_by);
CREATE INDEX idx_disposals_batch ON inventory_disposals(batch_id);
CREATE INDEX idx_disposals_staff ON inventory_disposals(disposed_by);

CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);
CREATE INDEX idx_orders_subscription ON orders(subscription_id);
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);
CREATE INDEX idx_order_details_item ON order_details(order_item_id);
CREATE INDEX idx_order_details_batch ON order_details(batch_id);

CREATE INDEX idx_payments_order ON payments(order_id);
CREATE INDEX idx_payments_subscription ON payments(subscription_id);
CREATE INDEX idx_payments_status ON payments(status);

CREATE INDEX idx_subscriptions_customer ON subscriptions(customer_id);
CREATE INDEX idx_sub_items_sub ON subscription_items(subscription_id);
CREATE INDEX idx_schedules_pending_date ON delivery_schedules(delivery_date) WHERE status = 'pending';
CREATE INDEX idx_schedules_sub ON delivery_schedules(subscription_id);

CREATE INDEX idx_complaints_status_created ON complaints(status, created_at ASC);
CREATE INDEX idx_complaints_item ON complaints(order_item_id);
CREATE INDEX idx_complaint_media_complaint ON complaint_media(complaint_id);

CREATE INDEX idx_reviews_product ON reviews(product_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_addresses_user ON addresses(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_cart_items_cart ON cart_items(cart_id);
CREATE INDEX idx_products_category ON products(category_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_product_images_product ON product_images(product_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_certifications_product ON quality_certifications(product_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_notifications_unread ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX idx_activity_logs_entity ON activity_logs(entity_type, entity_id);
CREATE INDEX idx_activity_logs_user ON activity_logs(user_id, created_at DESC);
