# farmly-db-schema

Lược đồ cơ sở dữ liệu của **Farmly – Website thương mại điện tử nông sản sạch** (Supabase / PostgreSQL), quản lý bằng **migration** theo cấu trúc của Supabase CLI.

## Cấu trúc thư mục

```
farmly-db-schema/
├── supabase/
│   ├── migrations/                                   # chạy theo thứ tự timestamp trong tên file
│   │   ├── 20261127000001_create_enums_and_tables.sql    # 16 ENUM, 24 bảng (3NF)
│   │   ├── 20261127000002_create_indexes.sql             # 35 index phụ (FEFO, đơn hàng, FK, xoá mềm)
│   │   ├── 20261127000003_create_triggers.sql            # updated_at, lô đúng sản phẩm, xuất huỷ, tạo profile, xoá mềm
│   │   ├── 20261127000004_create_fefo_function.sql       # hàm allocate_fefo (FOR UPDATE)
│   │   └── 20261127000005_enable_rls_and_settings.sql    # RLS, chính sách phân quyền, cấu hình mặc định
│   └── seed.sql                                      # dữ liệu mẫu để test FEFO
├── tests/
│   └── test_fefo.sql                                 # 4 ca kiểm thử hàm allocate_fefo
└── README.md
```

## Cách chạy

### Cách 1 – Supabase Dashboard (không cần cài gì)
1. Mở project → **SQL Editor** → **New query**.
2. Lần lượt dán và **Run** 5 file trong `supabase/migrations/` theo đúng thứ tự tên file (chỉ làm với CSDL **trống**).
3. Chạy `supabase/seed.sql` để nạp dữ liệu mẫu (chạy lại nhiều lần được, tồn kho các lô test về số ban đầu).

### Cách 2 – Supabase CLI
```bash
supabase link --project-ref <project-ref>
supabase db push            # áp dụng các migration chưa chạy
supabase db reset           # (môi trường local) tạo lại CSDL từ migrations + seed.sql
```

## Dữ liệu mẫu (seed.sql)

- 4 tài khoản (mật khẩu `Farmly@123`): `admin@farmly.vn`, `staff@farmly.vn`, `sales@farmly.vn`, `customer@gmail.com`
- 3 danh mục, 3 sản phẩm, 9 lô hàng phục vụ test FEFO:

| Sản phẩm | Lô | Hạn dùng | Tồn | Vai trò trong test |
|---|---|---|---|---|
| Cải thìa | BATCH-CAITHIA-01 | +2 ngày | 3 kg | Cận hạn → lấy trước |
| Cải thìa | BATCH-CAITHIA-02 | +7 ngày | 25 kg | Lấy tiếp |
| Cải thìa | BATCH-CAITHIA-EXPIRED | −1 ngày | 5 kg | Quá hạn → bỏ qua |
| Cải thìa | BATCH-CAITHIA-SOLDOUT | +5 ngày | 0 kg | Hết hàng → bỏ qua |
| Cải thìa | BATCH-CAITHIA-GROWING | – | 25 kg | Đang trồng → bỏ qua |
| Cà chua bi | BATCH-CACHUA-01 / 02 | +5 / +12 ngày | 3 / 50 kg | Ví dụ của đề: 10 kg = 3 + 7 |
| Xà lách | BATCH-XALACH-01 / 02 | +3 / +4 ngày | 5 / 3 kg | Tổng 8 kg → đặt 10 kg phải báo lỗi |

## Kiểm thử FEFO (tests/test_fefo.sql)

Trong SQL Editor, bôi đen từng ca rồi **Run**:

| Ca | Kết quả đúng |
|---|---|
| 1. Mua 10 kg cà chua | 3 kg từ BATCH-CACHUA-01 + 7 kg từ BATCH-CACHUA-02 |
| 2. Mua 10 kg cải thìa | 3 kg + 7 kg, bỏ qua lô quá hạn / hết hàng / đang trồng |
| 3. Mua 10 kg xà lách | Lỗi `Không đủ tồn kho khả dụng ... (thiếu 2.00 đơn vị)`, rollback |
| 3b. Kiểm tra sau ca 3 | Kho xà lách vẫn 5 kg và 3 kg, không còn đơn test |
| 4. Ghi nhầm lô | Trigger báo lỗi `Lô hàng (5) không thuộc sản phẩm của dòng đơn hàng` |
