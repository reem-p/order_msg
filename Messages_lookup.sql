CREATE TABLE dbo.Message_Types (
    msg_type INT PRIMARY KEY,
    msg_name NVARCHAR(100),
    msg_template NVARCHAR(MAX),
    is_active BIT DEFAULT 1,
    created_at DATETIME DEFAULT GETDATE()
);

INSERT INTO dbo.Message_Types (msg_type, msg_name, msg_template)
VALUES
(1, N'طلب سداد - مقايسة', N'رجاء سداد مقايسة كهرباء عداد بـقيمة {msg_amt} طلب رقم {oh_no} باسم/{oh_name}، شمال القاهرة'),
(2, N'شكرا لسداد - مقايسة', N'نشكركم على سداد مقايسة كهرباء عداد بـقيمة {msg_amt} طلب رقم {oh_no} باسم/{oh_name}، شمال القاهرة'),
(3, N'طلب سداد - قسط', N'رجاء سداد قسط تركيب عداد كهرباء بـقيمة {msg_amt} طلب رقم {oh_no} باسم/{oh_name}، شمال القاهرة'),
(4, N'شكرا لسداد - قسط', N'نشكركم على سداد قسط تركيب عداد كهرباء بـقيمة {msg_amt} طلب رقم {oh_no} باسم/{oh_name}، شمال القاهرة');
(5, N'شكرا لسداد - قسط', N'نشكركم على السداد OTP = {otp}');
