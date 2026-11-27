-- Farmly – Hàm allocate_fefo – xuất kho theo lô cận hạn (FOR UPDATE)
-- Supabase migration, chạy theo thứ tự tên file (timestamp).

-- Đã vá: ép kiểu CASE sang batch_status_enum (bản cũ báo lỗi kiểu text).

-- 5. HÀM NGHIỆP VỤ XUẤT KHO FEFO (RPC: allocate_fefo)
CREATE OR REPLACE FUNCTION allocate_fefo(p_order_id INT)
RETURNS VOID AS $$
DECLARE
    v_item RECORD;
    v_batch RECORD;
    v_remaining DECIMAL(10,2);
    v_take DECIMAL(10,2);
BEGIN
    -- Lặp qua từng dòng sản phẩm khách đặt trong đơn
    FOR v_item IN
        SELECT id, product_id, product_name, quantity
        FROM order_items
        WHERE order_id = p_order_id
        ORDER BY id ASC
    LOOP
        v_remaining := v_item.quantity;

        -- Khóa các lô hợp lệ (còn tồn > 0 và chưa hết hạn) ưu tiên exp_date gần nhất
        FOR v_batch IN
            SELECT id, current_quantity
            FROM batches
            WHERE product_id = v_item.product_id
              AND status = 'in_stock'
              AND current_quantity > 0
              AND exp_date > CURRENT_DATE
            ORDER BY exp_date ASC, created_at ASC
            FOR UPDATE
        LOOP
            EXIT WHEN v_remaining <= 0;

            v_take := LEAST(v_remaining, v_batch.current_quantity);

            -- Trừ tồn kho lô
            UPDATE batches
            SET current_quantity = current_quantity - v_take,
                status = (CASE WHEN (current_quantity - v_take) = 0 THEN 'sold_out' ELSE 'in_stock' END)::batch_status_enum
            WHERE id = v_batch.id;

            -- Ghi nhận xuất kho theo lô vào order_details
            INSERT INTO order_details (order_item_id, batch_id, quantity)
            VALUES (v_item.id, v_batch.id, v_take);

            v_remaining := v_remaining - v_take;
        END LOOP;

        -- Nếu duyệt hết lô mà vẫn thiếu hàng -> Ném lỗi để Rollback toàn bộ transaction
        IF v_remaining > 0 THEN
            RAISE EXCEPTION 'Không đủ tồn kho khả dụng cho sản phẩm "%" (thiếu % đơn vị)', v_item.product_name, v_remaining;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
